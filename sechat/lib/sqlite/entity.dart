import 'helper/sqlite.dart';


///
///  Store metas, documents, users, contacts, group members
///
///     file path: '/data/data/chat.dim.sechat/databases/mkm.db'
///


class EntityDatabase extends DatabaseConnector {
  EntityDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) {
        // meta
        DatabaseConnector.createTable(db, tMeta, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "did VARCHAR(64) NOT NULL UNIQUE",
          "type INTEGER NOT NULL",
          "pub_key TEXT NOT NULL",
          "seed VARCHAR(32)",
          "fingerprint VARCHAR(172)",
        ]);
        DatabaseConnector.createIndex(db, tMeta,
            name: 'meta_id_index', fields: ['did']);
        // document
        DatabaseConnector.createTable(db, tDocument, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "did VARCHAR(64) NOT NULL",
          "type VARCHAR(16)",
          "data TEXT NOT NULL",
          "signature VARCHAR(172) NOT NULL",
        ]);
        DatabaseConnector.createIndex(db, tDocument,
            name: 'doc_id_index', fields: ['did']);
        // local user
        DatabaseConnector.createTable(db, tLocalUser, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "uid VARCHAR(64) NOT NULL UNIQUE",
          "chosen BIT",
        ]);
        // contact
        DatabaseConnector.createTable(db, tContact, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "uid VARCHAR(64) NOT NULL",
          "contact VARCHAR(64) NOT NULL",
          "alias VARCHAR(32)",
        ]);
        DatabaseConnector.createIndex(db, tContact,
            name: 'user_id_index', fields: ['uid']);
        // group
        // member
        DatabaseConnector.createTable(db, tMember, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "gid VARCHAR(64) NOT NULL",
          "member VARCHAR(64) NOT NULL",
        ]);
        DatabaseConnector.createIndex(db, tMember,
            name: 'group_id_index', fields: ['gid']);
      },
      onUpgrade: (db, oldVersion, newVersion) {
        // TODO:
      });

  static const String dbName = 'mkm.db';
  static const int dbVersion = 1;

  static const String tMeta     = 't_meta';
  static const String tDocument = 't_document';

  static const String tLocalUser     = 't_local_user';
  static const String tContact  = 't_contact';

  static const String tGroup    = 't_group';
  static const String tMember   = 't_member';

}


Meta _extractMeta(ResultSet resultSet, int index) {
  int? type = resultSet.getInt('type');
  String? json = resultSet.getString('pub_key');
  Map? key = JSON.decode(json!);

  Map info = {
    'version': type,
    'type': type,
    'key': key,
  };
  if (MetaType.hasSeed(type!)) {
    info['seed'] = resultSet.getString('seed');
    info['fingerprint'] = resultSet.getString('fingerprint');
  }
  return Meta.parse(info)!;
}

class MetaTable extends DataTableHandler<Meta> implements MetaDBI {
  MetaTable() : super(EntityDatabase(), _extractMeta);

  static const String _table = EntityDatabase.tMeta;
  static const List<String> _selectColumns = ["type", "pub_key", "seed", "fingerprint"];
  static const List<String> _insertColumns = ["did", "type", "pub_key", "seed", "fingerprint"];

  @override
  Future<Meta?> getMeta(ID entity) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.string);
    List<Meta> array = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);
    // return first record only
    return array.isEmpty ? null : array[0];
  }

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    // make sure old records not exists
    Meta? old = await getMeta(entity);
    if (old != null) {
      // meta info won't changed, no need to update
      return false;
    }
    int type = meta.type;
    String json = JSON.encode(meta.key.dictionary);
    String seed;
    String fingerprint;
    if (MetaType.hasSeed(type)) {
      seed = meta.seed!;
      fingerprint = meta.getString('fingerprint')!;
    } else {
      seed = '';
      fingerprint = '';
    }
    List values = [entity.string, type, json, seed, fingerprint];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
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

class DocumentTable extends DataTableHandler<Document> implements DocumentDBI {
  DocumentTable() : super(EntityDatabase(), _extractDocument);

  static const String _table = EntityDatabase.tDocument;
  static const List<String> _selectColumns = ["did", "type", "data", "signature"];
  static const List<String> _insertColumns = ["did", "type", "data", "signature"];

  @override
  Future<Document?> getDocument(ID entity, String? type) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.string);
    List<Document> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // return first record only
    return array.isEmpty ? null : array[0];
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    ID identifier = doc.identifier;
    String? type = doc.type;
    String? data = doc.getString('data');
    String? signature = doc.getString('signature');

    Document? old = await getDocument(identifier, type);
    if (old == null) {
      // old record not found, insert it as new record
      List values = [identifier.string, type, data, signature];
      return await insert(_table, columns: _insertColumns, values: values) > 0;
    }
    if (old.getString('data') == data && old.getString('signature') == signature) {
      // same document
      return true;
    }
    // old record exists, update it
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: identifier.string);
    Map<String, dynamic> values = {
      'type': type,
      'data': data,
      'signature': signature,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

}
