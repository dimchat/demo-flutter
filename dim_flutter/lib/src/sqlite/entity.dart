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
        _createContactTable(db);

        // alias
        _createRemarkTable(db);
        // block-list
        _createBlockedTable(db);
        // mute-list
        _createMutedTable(db);

      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 5) {
          _createRemarkTable(db);
          _createBlockedTable(db);
          _createMutedTable(db);
        }
      });

  // contact
  static void _createContactTable(Database db) {
    DatabaseConnector.createTable(db, tContact, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "contact VARCHAR(64) NOT NULL",
    ]);
    DatabaseConnector.createIndex(db, tContact,
        name: 'user_id_index', fields: ['uid']);
  }
  // alias
  static void _createRemarkTable(Database db) {
    DatabaseConnector.createTable(db, tRemark, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "contact VARCHAR(64) NOT NULL",
      "alias VARCHAR(32)",
      "description TEXT",
    ]);
    DatabaseConnector.createIndex(db, tRemark,
        name: 'user_id_index', fields: ['uid']);
  }

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
  static const int dbVersion = 5;

  static const String tMeta     = 't_meta';
  static const String tDocument = 't_document';

  static const String tLocalUser = 't_local_user';
  static const String tContact   = 't_contact';

  static const String tRemark    = 't_remark';
  static const String tBlocked   = 't_blocked';
  static const String tMuted   = 't_muted';

}


///
///  Store group info
///
///     file path: '/data/data/chat.dim.sechat/databases/group.db'
///


class GroupDatabase extends DatabaseConnector {
  GroupDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) {
        // // reset group command
        // DatabaseConnector.createTable(db, tResetGroup, fields: [
        //   "id INTEGER PRIMARY KEY AUTOINCREMENT",
        //   "gid VARCHAR(64) NOT NULL",
        //   "cmd TEXT NOT NULL",
        //   "msg TEXT NOT NULL",
        // ]);
        // DatabaseConnector.createIndex(db, tResetGroup,
        //     name: 'gid_index', fields: ['gid']);
        // members
        _createMemberTable(db);
        // administrators
        _createAdminTable(db);
        // group history commands
        _createHistoryTable(db);
      }, onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          _createMemberTable(db);
          _createAdminTable(db);
          _createHistoryTable(db);
        }
      });

  // members
  static void _createMemberTable(Database db) {
    DatabaseConnector.createTable(db, tMember, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",
      "member VARCHAR(64) NOT NULL",
    ]);
    DatabaseConnector.createIndex(db, tMember,
        name: 'group_id_index', fields: ['gid']);
  }

  // administrators
  static void _createAdminTable(Database db) {
    DatabaseConnector.createTable(db, tAdmin, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",
      "admin VARCHAR(64) NOT NULL",
    ]);
    DatabaseConnector.createIndex(db, tAdmin,
        name: 'group_id_index', fields: ['gid']);
  }

  // group history commands
  static void _createHistoryTable(Database db) {
    DatabaseConnector.createTable(db, tHistory, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",  // group id
      "cmd VARCHAR(32) NOT NULL",  // command name
      "time INTEGER NOT NULL",     // command time (seconds)
      "content TEXT NOT NULL",     // command info
      "message TEXT NOT NULL",     // message info
    ]);
    DatabaseConnector.createIndex(db, tHistory,
        name: 'gid_index', fields: ['gid']);
  }

  static const String dbName = 'group.db';
  static const int dbVersion = 2;

  static const String tAdmin         = 't_admin';
  static const String tMember        = 't_member';

  static const String tHistory       = 't_history';

  // static const String tResetGroup = 't_reset_group';
}
