import 'package:dim_client/common.dart';

import 'helper/sqlite.dart';


///
///  Store metas, documents, users, contacts, group members
///
///     file path: '/data/data/chat.dim.sechat/databases/mkm.db'
///


class EntityDatabase extends DatabaseConnector {
  EntityDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) async {
        // meta
        await _createMetaTable(db);
        // document
        await _createDocumentTable(db);
        // visa
        await _createVisaTable(db);

        // local user
        await _createLocalUserTable(db);

        // contact
        await _createContactTable(db);
        // alias
        await _createRemarkTable(db);

        // block-list
        await _createBlockedTable(db);
        // mute-list
        await _createMutedTable(db);

      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          await _createRemarkTable(db);
          await _createBlockedTable(db);
          await _createMutedTable(db);
        }
        if (oldVersion < 6) {
          await _createVisaTable(db);
          await _moveVisaDocuments(db);
        }
      });

  // meta
  static Future<void> _createMetaTable(Database db) async {
    await DatabaseConnector.createTable(db, tMeta, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "did VARCHAR(64) NOT NULL UNIQUE",
      "type INTEGER NOT NULL",
      "pub_key TEXT NOT NULL",
      "seed VARCHAR(32)",
      "fingerprint VARCHAR(172)",
    ]);
    await DatabaseConnector.createIndex(db, tMeta,
      name: 'meta_id_index', columns: ['did'],
    );
  }
  // document
  static Future<void> _createDocumentTable(Database db) async {
    await DatabaseConnector.createTable(db, tDocument, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "did VARCHAR(64) NOT NULL",
      "type VARCHAR(16)",
      "data TEXT NOT NULL",
      "signature VARCHAR(172) NOT NULL",
    ]);
    await DatabaseConnector.createIndex(db, tDocument,
      name: 'doc_id_index', columns: ['did'],
    );
  }

  // visa document
  static Future<void> _createVisaTable(Database db) async {
    await DatabaseConnector.createTable(db, tVisa, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "did VARCHAR(64) NOT NULL",
      "terminal VARCHAR(32)",
      "type VARCHAR(16)",
      "data TEXT NOT NULL",
      "signature VARCHAR(172) NOT NULL",
    ]);
    await DatabaseConnector.createIndex(db, tVisa,
      name: 'visa_id_index', columns: ['did'],
    );
  }
  static Future<void> _moveVisaDocuments(Database db) async {
    var cond = SQLConditions.compare('type', '<>', DocumentType.BULLETIN);
    // copy records to t_visa
    await DatabaseConnector.copyTable(db, tVisa,
      columns: ["did", "terminal", "type", "data", "signature"],
      fromColumns: ["did", "''", "type", "data", "signature"],
      fromTable: tDocument,
      conditions: cond,
    );
    // // remove records from t_document
    // String sql = SQLBuilder.buildDelete(tDocument, conditions: cond);
    // DBLogger.output('rename visa record from t_document: $sql');
    // await db.execute(sql);
  }

  // local user
  static Future<void> _createLocalUserTable(Database db) async {
    await DatabaseConnector.createTable(db, tLocalUser, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL UNIQUE",
      "chosen BIT",
    ]);
  }

  // contact
  static Future<void> _createContactTable(Database db) async {
    await DatabaseConnector.createTable(db, tContact, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "contact VARCHAR(64) NOT NULL",
    ]);
    await DatabaseConnector.createIndex(db, tContact,
      name: 'user_id_index', columns: ['uid'],
    );
  }
  // alias
  static Future<void> _createRemarkTable(Database db) async {
    await DatabaseConnector.createTable(db, tRemark, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "contact VARCHAR(64) NOT NULL",
      "alias VARCHAR(32)",
      "description TEXT",
    ]);
    await DatabaseConnector.createIndex(db, tRemark,
      name: 'user_id_index', columns: ['uid'],
    );
  }

  // block-list
  static Future<void> _createBlockedTable(Database db) async {
    await DatabaseConnector.createTable(db, tBlocked, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "blocked VARCHAR(64) NOT NULL",  // contact ID
    ]);
    await DatabaseConnector.createIndex(db, tBlocked,
      name: 'user_id_index', columns: ['uid'],
    );
  }
  // mute-list
  static Future<void> _createMutedTable(Database db) async {
    await DatabaseConnector.createTable(db, tMuted, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",
      "muted VARCHAR(64) NOT NULL",  // contact ID
    ]);
    await DatabaseConnector.createIndex(db, tMuted,
      name: 'user_id_index', columns: ['uid'],
    );
  }

  static const String dbName = 'mkm.db';
  static const int dbVersion = 6;

  static const String tMeta     = 't_meta';
  static const String tVisa     = 't_visa';
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
      onCreate: (db, version) async {
        // // reset group command
        // DatabaseConnector.createTable(db, tResetGroup, fields: [
        //   "id INTEGER PRIMARY KEY AUTOINCREMENT",
        //   "gid VARCHAR(64) NOT NULL",
        //   "cmd TEXT NOT NULL",
        //   "msg TEXT NOT NULL",
        // ]);
        // DatabaseConnector.createIndex(db, tResetGroup,
        //     name: 'gid_index', columns: ['gid']);
        // members
        await _createMemberTable(db);
        // administrators
        await _createAdminTable(db);
        // group history commands
        await _createHistoryTable(db);
      }, onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createMemberTable(db);
          await _createAdminTable(db);
          await _createHistoryTable(db);
        }
      });

  // members
  static Future<void> _createMemberTable(Database db) async {
    await DatabaseConnector.createTable(db, tMember, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",
      "member VARCHAR(64) NOT NULL",
    ]);
    await DatabaseConnector.createIndex(db, tMember,
      name: 'group_id_index', columns: ['gid'],
    );
  }

  // administrators
  static Future<void> _createAdminTable(Database db) async {
    await DatabaseConnector.createTable(db, tAdmin, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",
      "admin VARCHAR(64) NOT NULL",
    ]);
    await DatabaseConnector.createIndex(db, tAdmin,
      name: 'group_id_index', columns: ['gid'],
    );
  }

  // group history commands
  static Future<void> _createHistoryTable(Database db) async {
    await DatabaseConnector.createTable(db, tHistory, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",  // group id
      "cmd VARCHAR(32) NOT NULL",  // command name
      "time INTEGER NOT NULL",     // command time (seconds)
      "content TEXT NOT NULL",     // command info
      "message TEXT NOT NULL",     // message info
    ]);
    await DatabaseConnector.createIndex(db, tHistory,
      name: 'gid_index', columns: ['gid'],
    );
  }

  static const String dbName = 'group.db';
  static const int dbVersion = 2;

  static const String tAdmin         = 't_admin';
  static const String tMember        = 't_member';

  static const String tHistory       = 't_history';

  // static const String tResetGroup = 't_reset_group';
}
