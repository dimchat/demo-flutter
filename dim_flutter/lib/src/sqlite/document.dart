
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


String? getDocumentTerminal(Document document) {
  if (document is Visa) {
    return document.terminal;
  }
  // bulletin document has no terminal
  return null;
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
  Future<List<Document>> loadDocuments(ID identifier) async {
    ID did = identifier.withoutTerminal();
    var cond = SQLConditions.compare('did', '=', did.toString());
    if (identifier.isUser) {
      // user documents were moved to "t_visa"
      return await select(_visaTable, columns: _selectVisaColumns, conditions: cond);
    }
    // load group documents
    assert(identifier.isGroup, 'group ID error: $identifier');
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  // protected
  Future<bool> updateDocument(Document doc, ID identifier) async {
    ID did = identifier.withoutTerminal();
    String type = doc.type ?? '';
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
    var cond = SQLConditions.compare('did', '=', did.toString());
    cond = cond.andCompare('type', '=', type);
    Map<String, dynamic> values = {
      'data': data,
      'signature': signature,
    };
    if (identifier.isUser) {
      // update user document into "t_visa"
      String? terminal = getDocumentTerminal(doc);
      terminal ??= identifier.terminal ?? '';
      cond = cond.andCompare('terminal', '=', terminal);
      return await update(_visaTable, values: values, conditions: cond) > 0;
    }
    // update group document
    assert(identifier.isGroup, 'group ID error: $identifier');
    return await update(_table, values: values, conditions: cond) > 0;
  }

  // protected
  Future<bool> insertDocument(Document doc, ID identifier) async {
    ID did = identifier.withoutTerminal();
    String type = doc.type ?? '';
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');
    List values = [
      did.toString(),
      type,
      data,
      signature,
    ];
    if (identifier.isUser) {
      // add user document into "t_visa"
      String? terminal = getDocumentTerminal(doc);
      terminal ??= identifier.terminal ?? '';
      values.insert(1, terminal);
      return await insert(_visaTable, columns: _insertVisaColumns, values: values) > 0;
    }
    // add group document
    assert(identifier.isGroup, 'group ID error: $identifier');
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
    return DocumentUtils.trimDocuments(docs);
  }

  @override
  Future<bool> writeData(List<Document> documents) async {
    Document? doc = _newDocument;
    if (doc == null) {
      assert(false, 'should not happen: $_entity');
      return false;
    }
    ID identifier = doc.identifier;
    assert(_entity.isSameAs(identifier), 'document ID not matched: $_entity, $doc');
    String type = doc.type ?? '';
    String terminal = getDocumentTerminal(doc) ?? '';
    bool update = false;
    Document item;
    // check old documents
    for (int index = documents.length - 1; index >= 0; --index) {
      item = documents[index];
      if (identifier != item['did']) {
        assert(false, 'document error: $identifier, $item');
        continue;
      } else if (item.type != type) {
        logInfo('skip document: $identifier, type=$type, $item');
        continue;
      } else if (identifier.isUser && getDocumentTerminal(item) != terminal) {
        logInfo('skip visa: $identifier, terminal=$terminal, $item');
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
      DocumentUtils.sortDocuments(documents);
      // update old record
      return await _table.updateDocument(doc, identifier);
    }
    // add new record
    var ok = await _table.insertDocument(doc, identifier);
    if (ok) {
      documents.add(doc);
      DocumentUtils.sortDocuments(documents);
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
  Future<bool> saveDocument(Document doc, ID identifier) async {
    //
    //  0. check valid
    //
    assert(identifier == doc['did'], 'document ID not matched: $identifier, $doc');
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
