import 'package:lnc/lnc.dart';

import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'entity.dart';


Document _extractDocument(ResultSet resultSet, int index) {
  String? did = resultSet.getString('did');
  String? type = resultSet.getString('type');
  String? data = resultSet.getString('data');
  String? signature = resultSet.getString('signature');
  ID? identifier = ID.parse(did);
  assert(identifier != null, 'did error: $did');
  assert(data != null && signature != null, 'document error: $data, $signature');
  if (type == null || type.isEmpty) {
    type = '*';
  }
  Document? doc = Document.create(type, identifier!, data: data, signature: signature);
  assert(doc != null, 'document error: $did, $type, $data, $signature');
  if (type == '*') {
    if (identifier.isUser) {
      type = Document.kVisa;
    } else {
      type = Document.kBulletin;
    }
  }
  doc!['type'] = type;
  return doc;
}

class _DocumentTable extends DataTableHandler<Document> implements DocumentDBI {
  _DocumentTable() : super(EntityDatabase(), _extractDocument);

  static const String _table = EntityDatabase.tDocument;
  static const List<String> _selectColumns = ["did", "type", "data", "signature"];
  static const List<String> _insertColumns = ["did", "type", "data", "signature"];

  @override
  Future<Document?> getDocument(ID entity, String? type) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.toString());
    List<Document> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    return array.isEmpty ? null : array[0];
  }

  Future<bool> updateDocument(Document doc) async {
    ID identifier = doc.identifier;
    String? type = doc.type;
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: identifier.toString());
    Map<String, dynamic> values = {
      'type': type,
      'data': data,
      'signature': signature,
    };
    return await update(_table, values: values, conditions: cond) == 1;
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    ID identifier = doc.identifier;
    String? type = doc.type;
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
    List values = [identifier.toString(), type, data, signature];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class DocumentCache extends _DocumentTable {

  final CachePool<ID, Document> _cache = CacheManager().getPool('document');

  @override
  Future<Document?> getDocument(ID entity, String? type) async {
    double now = Time.currentTimeSeconds;
    // 1. check memory cache
    CachePair<Document>? pair = _cache.fetch(entity, now: now);
    CacheHolder<Document>? holder = pair?.holder;
    Document? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
        _cache.updateValue(entity, null, 128, now: now);
      } else {
        if (holder.isAlive(now: now)) {
          // value not exists
          return null;
        }
        // cache expired, wait to reload
        holder.renewal(128, now: now);
      }
      // 2. load from database
      value = await super.getDocument(entity, type);
      // update cache
      _cache.updateValue(entity, value, 3600, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    // 0. check valid
    if (!doc.isValid) {
      Log.error('document not valid: ${doc.identifier}');
      return false;
    }
    ID identifier = doc.identifier;
    bool ok;
    // 1. check old record
    Document? old = await getDocument(identifier, doc.type);
    if (old == null) {
      // insert as new record
      ok = await super.saveDocument(doc);
    } else if (old.getString('signature') == doc.getString('signature')) {
      // same document
      Log.warning('duplicated document: $identifier');
      return true;
    } else if (_isDocumentExpired(doc, old)) {
      Log.warning('expired document: $identifier');
      return false;
    } else {
      // update old record
      ok = await super.updateDocument(doc);
    }
    if (ok) {
      // update cache
      _cache.updateValue(identifier, doc, 3600, now: Time.currentTimeSeconds);
    } else {
      Log.error('failed to save document: $identifier');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kDocumentUpdated, this, {
      'ID': identifier,
      'document': doc,
    });
    return true;
  }

}

bool _isDocumentExpired(Document newOne, Document oldOne) {
  DateTime? oldTime = oldOne.time;
  if (oldTime == null) {
    Log.warning('document time not found: ${oldOne.identifier}');
    return false;
  }
  DateTime? newTime = newOne.time;
  if (newTime == null) {
    Log.warning('document time not found: ${newOne.identifier}');
    return false;
  }
  return !newTime.isAfter(oldTime);
}
