
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


String getDocumentTerminal(Document document) {
  if (document is Visa) {
    String? terminal = document.terminal;
    if (terminal == null || terminal == '*') {
      terminal = '';
    }
    return terminal;
  }
  // bulletin document has no terminal
  return '';
}

bool _docTypeNotMatch(String? type1, String? type2) {
  type1 ??= '';
  type2 ??= '';
  if (type1 == '*' || type2 == '*') {
    return false;
  }
  return type1 != type2;
}

List<Document> _sortDocuments(List<Document> documents, ID entity) {
  int total = documents.length;
  if (total > 1) {
    // 1. Sort documents by timestamp descending
    DocumentUtils.sortDocuments(documents);
    // 2. Remove duplicated items by signature
    DocumentUtils.tidyDocuments(documents);
    // TODO: remove expired document(s)
    if (documents.length > 8) {
      documents.length = 8;
    }
  }
  int count = documents.length;
  if (count < total) {
    Log.info('trim $count/$total document(s) for $entity');
  }
  return documents;
}


Document _extractDocument(ResultSet resultSet, int index) {
  String? did = resultSet.getString('did');
  String? terminal = resultSet.getString('terminal');
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
  Document doc = Document.create(type, data: data, signature: ted);
  doc.setString('did', identifier);
  if (terminal != null) {
    doc['terminal'] = terminal;
  }
  if (type == '*') {
    if (identifier == null) {
      assert(false, 'document error: $did, $terminal, data: $data signature: $signature');
      type = DocumentType.PROFILE;
    } else if (identifier.isUser) {
      type = DocumentType.VISA;
    } else {
      type = DocumentType.BULLETIN;
    }
  }
  doc['type'] = type;
  return doc;
}

class _DocumentTable extends DataTableHandler<Document> {
  _DocumentTable() : super(EntityDatabase(), _extractDocument);

  static const String _table = EntityDatabase.tDocument;
  static const List<String> _selectColumns = ["did", "type", "data", "signature"];
  static const List<String> _insertColumns = ["did", "type", "data", "signature"];

  static const String _visaTable = EntityDatabase.tVisa;
  static const List<String> _selectVisaColumns = ["did", "terminal", "type", "data", "signature"];
  static const List<String> _insertVisaColumns = ["did", "terminal", "type", "data", "signature"];

  // protected
  Future<List<Document>> loadDocuments(final ID entity) async {
    var cond = SQLConditions.compare('did', '=', entity.toString());
    if (entity.isUser) {
      // user documents were moved to "t_visa"
      return await select(_visaTable, columns: _selectVisaColumns, conditions: cond);
    }
    // load group documents
    assert(entity.isGroup, 'group ID error: $entity');
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  // protected
  Future<bool> updateDocument(Document doc, final ID entity) async {
    String type = doc.type ?? '';
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
    var cond = SQLConditions.compare('did', '=', entity.toString());
    cond = cond.andCompare('type', '=', type);
    Map<String, dynamic> values = {
      'data': data,
      'signature': signature,
    };
    if (entity.isUser) {
      // update user document into "t_visa"
      String terminal = getDocumentTerminal(doc);
      cond = cond.andCompare('terminal', '=', terminal);
      return await update(_visaTable, values: values, conditions: cond) > 0;
    }
    // update group document
    assert(entity.isGroup, 'group ID error: $entity');
    return await update(_table, values: values, conditions: cond) > 0;
  }

  // protected
  Future<bool> insertDocument(Document doc, final ID entity) async {
    String type = doc.type ?? '';
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
    List values = [
      entity.toString(),
      type,
      data,
      signature,
    ];
    if (entity.isUser) {
      // add user document into "t_visa"
      String terminal = getDocumentTerminal(doc);
      values.insert(1, terminal);
      return await insert(_visaTable, columns: _insertVisaColumns, values: values) > 0;
    }
    // add group document
    assert(entity.isGroup, 'group ID error: $entity');
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class _DocTask extends DbTask<ID, List<Document>> {
  _DocTask(super.mutexLock, super.cachePool, this._table, this._entity, {
    required Document? newDocument,
  }) : _newDocument = newDocument;

  final ID _entity;

  final Document? _newDocument;

  final _DocumentTable _table;

  @override
  ID get cacheKey => _entity;

  @override
  Future<List<Document>?> readData() async {
    var docs = await _table.loadDocuments(_entity);
    return _sortDocuments(docs, _entity);
  }

  @override
  Future<bool> writeData(List<Document> documents) async {
    Document? newDoc = _newDocument;
    if (newDoc == null) {
      assert(false, 'should not happen: $_entity');
      return false;
    }
    String? newType = newDoc.type;
    String newSignature = newDoc.getString('signature') ?? '';
    String newTerminal = getDocumentTerminal(newDoc);
    // check did
    ID? did = newDoc.identifier;
    if (did == null) {
      logWarning('document id not found: $_entity, $newDoc');
      // return false;
    } else if (!did.isSameAs(_entity)) {
      assert(false, 'document id not matched: $_entity, $newDoc');
      return false;
    }
    //
    //  0. check old documents
    //
    bool update = false;
    int total = documents.length;
    int index = 0;
    for (Document item in documents) {
      index += 1;
      // check document id
      did = item.identifier;
      if (did == null || !did.isSameAs(_entity)) {
        logError('[$index/$total] document id not matched: $_entity, $did => $item');
        // TODO: remove it?
        assert(did == null, 'document error: $_entity, $item');
        // continue;
      }
      // check duplicated
      if (item.getString('signature') == newSignature) {
        logWarning('[$index/$total] document exists: $did, sign=$newSignature.');
        return true;
      } else if (item == newDoc) {
        logWarning('[$index/$total] same document, no need to update: $did.');
        return true;
      }
      // check terminal & type
      String device = getDocumentTerminal(item);
      if (device != newTerminal) {
        logInfo('[$index/$total] skip document: $did, terminal=$device <> $newTerminal.');
        continue;
      } else if (_docTypeNotMatch(item.type, newType)) {
        logInfo('[$index/$total] skip document: $did, type=${item.type} <> $newType.');
        continue;
      }
      // old record found (same type, same terminal),
      // update it
      logInfo('[$index/$total] update document: $did, terminal=$newTerminal type=$newType.');
      documents[index - 1] = newDoc;
      update = true;
      // break;
    }
    if (update) {
      _sortDocuments(documents, _entity);
      // update old record
      return await _table.updateDocument(newDoc, _entity);
    } else {
      DateTime? when = Converter.getDateTime(newDoc.getProperty('created_time'));
      logInfo('insert new document: $_entity "$newTerminal", type="$newType", created=[$when].');
    }
    // add new record
    var ok = await _table.insertDocument(newDoc, _entity);
    if (ok) {
      documents.add(newDoc);
      _sortDocuments(documents, _entity);
    }
    return ok;
  }

}

class DocumentCache extends DataCache<ID, List<Document>> implements DocumentDBI {
  DocumentCache() : super('documents');

  final _DocumentTable _table = _DocumentTable();

  _DocTask _newTask(ID entity, {Document? newDocument}) {
    assert(entity.terminal == null, 'not a naked id: $entity');
    return _DocTask(mutexLock, cachePool, _table, entity, newDocument: newDocument);
  }

  @override
  Future<List<Document>> getDocuments(ID entity) async {
    var task = _newTask(entity);
    return await task.load() ?? [];
  }

  @override
  Future<bool> saveDocument(Document doc, ID entity) async {
    assert(doc.isValid, 'document invalid: $entity -> $doc');
    //
    //  1. load old records
    //
    var task = _newTask(entity);
    var documents = await task.load();
    if (documents == null) {
      documents = [];
    } else {
      String newTerm = getDocumentTerminal(doc);
      String? newType = doc.type;
      DateTime? newTime = doc.time;
      DateTime? oldTime;
      for (final item in documents) {
        if (getDocumentTerminal(item) != newTerm) {
          continue;
        } else if (_docTypeNotMatch(item.type, newType)) {
          continue;
        } else if (newTime == null) {
          assert(false, 'document time error: $entity, $item');
          continue;
        }
        // check expired
        oldTime = item.time;
        if (oldTime != null && oldTime.isAfter(newTime)) {
          logWarning('ignore expired document: $doc');
          return false;
        }
      }
    }
    //
    //  2. save new record
    //
    task = _newTask(entity, newDocument: doc);
    bool ok = await task.save(documents);
    if (!ok) {
      logError('failed to save document: $entity');
      return false;
    }
    //
    //  3. post notification
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kDocumentUpdated, this, {
      'ID': entity,
      'document': doc,
    });
    return true;
  }

}
