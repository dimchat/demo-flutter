import 'package:lnc/lnc.dart';

import '../common/constants.dart';
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
  TransportableData? ted = TransportableData.parse(signature);
  Document doc = Document.create(type, identifier!, data: data, signature: ted);
  if (type == '*') {
    if (identifier.isUser) {
      type = Document.kVisa;
    } else {
      type = Document.kBulletin;
    }
  }
  doc['type'] = type;
  return doc;
}

class _DocumentTable extends DataTableHandler<Document> implements DocumentDBI {
  _DocumentTable() : super(EntityDatabase(), _extractDocument);

  static const String _table = EntityDatabase.tDocument;
  static const List<String> _selectColumns = ["did", "type", "data", "signature"];
  static const List<String> _insertColumns = ["did", "type", "data", "signature"];

  @override
  Future<List<Document>> getDocuments(ID entity) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    ID identifier = doc.identifier;
    String? type = doc.getString('type', '');
    // check old documents
    List<Document> documents = await getDocuments(identifier);
    for (Document item in documents) {
      if (item.identifier != identifier) {
        assert(false, 'document error: $identifier, $item');
        continue;
      }
      if (item.getString('type', '') == type) {
        // old record found, update it
        if (item == doc) {
          Log.warning('same document, no need to update: $identifier');
          return true;
        }
        return await updateDocument(doc);
      }
    }
    // add new record
    return await insertDocument(doc);
  }

  // protected
  Future<bool> updateDocument(Document doc) async {
    ID identifier = doc.identifier;
    String? type = doc.getString('type', '');
    String? data = doc.getString('data', null);
    String? signature = doc.getString('signature', null);
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: identifier.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'type', comparison: '=', right: type);
    Map<String, dynamic> values = {
      'data': data,
      'signature': signature,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

  // protected
  Future<bool> insertDocument(Document doc) async {
    ID identifier = doc.identifier;
    String? type = doc.getString('type', '');
    String? data = doc.getString('data', null);
    String? signature = doc.getString('signature', null);
    List values = [identifier.toString(), type, data, signature];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class DocumentCache extends _DocumentTable {

  final CachePool<ID, List<Document>> _cache = CacheManager().getPool('document');

  @override
  Future<List<Document>> getDocuments(ID entity) async {
    CachePair<List<Document>>? pair;
    CacheHolder<List<Document>>? holder;
    List<Document>? value;
    double now = Time.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _cache.fetch(entity, now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value == null) {
        if (holder == null) {
          // not load yet, wait to load
        } else if (holder.isAlive(now: now)) {
          // value not exists
          return [];
        } else {
          // cache expired, wait to reload
          holder.renewal(128, now: now);
        }
        // 2. load from database
        value = await super.getDocuments(entity);
        // update cache
        _cache.updateValue(entity, value, 3600, now: now);
      }
    } finally {
      unlock();
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
    // 1. do save
    if (await super.saveDocument(doc)) {
      // clear to reload
      _cache.erase(identifier);
    } else {
      Log.error('failed to save document: $identifier');
      return false;
    }
    // 2. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kDocumentUpdated, this, {
      'ID': identifier,
      'document': doc,
    });
    return true;
  }

}
