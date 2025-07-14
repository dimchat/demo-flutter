
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


String getDocumentType(Document document) {
  // return DocumentUtils.getDocumentType(document) ?? '';
  var type = document.getString('type');
  if (type != null && type.isNotEmpty) {
    return Converter.getString(type) ?? '';
  }
  // get type for did
  var did = document.identifier;
  if (did.isUser) {
    return DocumentType.VISA;
  } else if (did.isGroup) {
    return DocumentType.BULLETIN;
  } else {
    return DocumentType.PROFILE;
  }
}


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

  // protected
  Future<List<Document>> loadDocuments(ID entity) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  // protected
  Future<bool> updateDocument(Document doc) async {
    ID identifier = doc.identifier;
    // String type = doc.getString('type') ?? '';
    String type = getDocumentType(doc);
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
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
    // String type = doc.getString('type') ?? '';
    String type = getDocumentType(doc);
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
    List values = [
      identifier.toString(),
      type,
      data,
      signature,
    ];
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
    return await _table.loadDocuments(_entity);
  }

  @override
  Future<bool> writeData(List<Document> documents) async {
    Document? doc = _newDocument;
    if (doc == null) {
      assert(false, 'should not happen: $_entity');
      return false;
    }
    ID identifier = doc.identifier;
    // String type = doc.getString('type') ?? '';
    String type = getDocumentType(doc);
    bool update = false;
    Document item;
    // check old documents
    for (int index = documents.length - 1; index >= 0; --index) {
      item = documents[index];
      if (item.identifier != identifier) {
        assert(false, 'document error: $identifier, $item');
        continue;
      } else if (getDocumentType(item) != type) {
        logInfo('skip document: $identifier, type=$type, $item');
        continue;
      } else if (item == doc) {
        logWarning('same document, no need to update: $identifier');
        return true;
      }
      // old record found, update it
      documents[index] = doc;
      update = true;
    }
    if (update) {
      // update old record
      return await _table.updateDocument(doc);
    }
    // add new record
    var ok = await _table.insertDocument(doc);
    if (ok) {
      documents.add(doc);
    }
    return ok;
  }

}

class DocumentCache extends DataCache<ID, List<Document>> implements DocumentDBI {
  DocumentCache() : super('documents');

  final _DocumentTable _table = _DocumentTable();

  _DocTask _newTask(ID entity, {Document? newDocument}) =>
      _DocTask(mutexLock, cachePool, _table, entity, newDocument: newDocument);

  @override
  Future<List<Document>> getDocuments(ID entity) async {
    var task = _newTask(entity);
    var documents = await task.load();
    return documents ?? [];
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    //
    //  0. check valid
    //
    ID identifier = doc.identifier;
    if (!doc.isValid) {
      logError('document not valid: $identifier');
      return false;
    }
    //
    //  1. load old records
    //
    var task = _newTask(identifier);
    var documents = await task.load();
    if (documents == null) {
      documents = [];
    } else {
      // check time
      DateTime? newTime = doc.time;
      if (newTime != null) {
        DateTime? oldTime;
        for (Document item in documents) {
          oldTime = item.time;
          if (oldTime != null && oldTime.isAfter(newTime)) {
            logWarning('ignore expired document: $doc');
            return false;
          }
        }
      }
    }
    //
    //  2. save new record
    //
    task = _newTask(identifier, newDocument: doc);
    bool ok = await task.save(documents);
    if (!ok) {
      logError('failed to save document: $identifier');
      return false;
    }
    //
    //  3. post notification
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kDocumentUpdated, this, {
      'ID': identifier,
      'document': doc,
    });
    return true;
  }

}
