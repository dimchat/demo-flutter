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

        // block-list
        _createBlockedTable(db);
        // mute-list
        _createMutedTable(db);

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
        if (oldVersion < 4) {
          _createBlockedTable(db);
          _createMutedTable(db);
        }
      });

  // block-list
  static void _createBlockedTable(Database db) {
    DatabaseConnector.createTable(db, tBlocked, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "blocked VARCHAR(64) NOT NULL",  // contact ID
    ]);
    DatabaseConnector.createIndex(db, tBlocked,
        name: 'user_id_index', fields: ['uid']);
  }
  // mute-list
  static void _createMutedTable(Database db) {
    DatabaseConnector.createTable(db, tMuted, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "muted VARCHAR(64) NOT NULL",  // contact ID
    ]);
    DatabaseConnector.createIndex(db, tMuted,
        name: 'user_id_index', fields: ['uid']);
  }

  static const String dbName = 'mkm.db';
  static const int dbVersion = 4;

  static const String tMeta     = 't_meta';
  static const String tDocument = 't_document';

  static const String tLocalUser = 't_local_user';
  static const String tContact   = 't_contact';

  static const String tBlocked   = 't_blocked';
  static const String tMuted   = 't_muted';

  static const String tGroup    = 't_group';
  static const String tMember   = 't_member';

}
