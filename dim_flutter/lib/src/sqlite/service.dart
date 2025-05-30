
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';


///
///  Store service providers, stations
///
///     file path: '/data/data/chat.dim.sechat/databases/sp.db'
///


class ServiceProviderDatabase extends DatabaseConnector {
  ServiceProviderDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) {
        // provider
        DatabaseConnector.createTable(db, tProvider, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "pid VARCHAR(64) NOT NULL UNIQUE",
          "chosen INTEGER",
        ]);
        // station
        DatabaseConnector.createTable(db, tStation, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "pid VARCHAR(64) NOT NULL",    // provider ID
          "host VARCHAR(128) NOT NULL",  // station IP or domain name
          "port INTEGER NOT NULL",       // station port
          "chosen INTEGER",
        ]);
        DatabaseConnector.createIndex(db, tStation,
            name: 'sp_id_index', fields: ['pid']);
        // access speed
        _createSpeedTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 3) {
          // add column for speed
          DatabaseConnector.addColumn(db, tSpeed, name: 'socket', type: 'VARCHAR(32)');
        }
        // ALTER TABLE t_speed ADD COLUMN socket VARCHAR(32),  // '255.255.255.255:65535'
      });

  // speed
  static void _createSpeedTable(Database db) {
    DatabaseConnector.createTable(db, tSpeed, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "host VARCHAR(128) NOT NULL",  // station IP or domain name
      "port INTEGER NOT NULL",       // station port
      "sid VARCHAR(64) NOT NULL",    // station ID
      "time INTEGER NOT NULL",       // last test time (seconds)
      "duration REAL NOT NULL",      // respond time (seconds)
      "socket VARCHAR(32)",          // socket address
    ]);
    DatabaseConnector.createIndex(db, tSpeed,
        name: 'ip_index', fields: ['host']);
  }

  static const String dbName = 'sp.db';
  static const int dbVersion = 3;

  static const String tProvider = 't_provider';
  static const String tStation  = 't_station';
  static const String tSpeed    = 't_speed';

}


ProviderInfo _extractProvider(ResultSet resultSet, int index) {
  String? sp = resultSet.getString('pid');
  int? chosen = resultSet.getInt('chosen');
  return ProviderInfo(ID.parse(sp)!, chosen!);
}

class _ProviderTable extends DataTableHandler<ProviderInfo> {
  _ProviderTable() : super(ServiceProviderDatabase(), _extractProvider);

  static const String _table = ServiceProviderDatabase.tProvider;
  static const List<String> _selectColumns = ["pid", "chosen"];
  static const List<String> _insertColumns = ["pid", "chosen"];

  // protected
  Future<List<ProviderInfo>> loadProviders() async {
    SQLConditions cond = SQLConditions.kTrue;
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  // protected
  Future<bool> addProvider(ID identifier, int chosen) async {
    // add new record
    List values = [
      identifier.toString(),
      chosen,
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add service provider: $identifier -> $chosen');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> updateProvider(ID identifier, int chosen) async {
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.toString());
    if (await update(_table, values: values, conditions: cond) < 1) {
      logError('failed to update service provider: $identifier -> $chosen');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> removeProvider(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove service provider: $identifier');
      return false;
    }
    return true;
  }

}

class _SpTask extends DbTask<String, List<ProviderInfo>> {
  _SpTask(super.mutexLock, super.cachePool, this._table, {
    required ID? append,
    required ID? update,
    required ID? remove,
    required int? chosen,
  }) : _append = append, _update = update, _remove = remove, _chosen = chosen;

  final ID? _append;
  final ID? _update;
  final ID? _remove;
  final int? _chosen;

  final _ProviderTable _table;

  @override
  String get cacheKey => 'service_providers';

  @override
  Future<List<ProviderInfo>?> readData() async {
    return await _table.loadProviders();
  }

  @override
  Future<bool> writeData(List<ProviderInfo> providers) async {
    int chosen = _chosen ?? 0;
    // 1. append
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addProvider(append, chosen);
      if (ok1) {
        // clear to reload
        cachePool.erase(cacheKey);
      }
    }
    // 2. update
    bool ok2 = false;
    ID? update = _update;
    if (update != null) {
      ok2 = await _table.updateProvider(update, chosen);
      if (ok2) {
        // clear to reload
        cachePool.erase(cacheKey);
      }
    }
    // 3. remove
    bool ok3 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok3 = await _table.removeProvider(remove);
      if (ok3) {
        providers.removeWhere((sp) => sp.identifier == remove);
      }
    }
    return ok1 || ok2;
  }

}

class ProviderCache extends DataCache<String, List<ProviderInfo>> implements ProviderDBI {
  ProviderCache() : super('service_providers');

  final _ProviderTable _table = _ProviderTable();

  _SpTask _newTask({ID? append, ID? update, ID? remove, int? chosen}) =>
      _SpTask(mutexLock, cachePool, _table,
          append: append,
          update: update,
          remove: remove,
          chosen: chosen);

  static int? _find(ID identifier, List<ProviderInfo> providers) {
    for (ProviderInfo item in providers) {
      if (item.identifier == identifier) {
        return item.chosen;
      }
    }
    return null;
  }

  @override
  Future<List<ProviderInfo>> allProviders() async {
    var task = _newTask();
    var providers = await task.load();
    return providers ?? [];
  }

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async {
    var task = _newTask();
    var providers = await task.load();
    providers ??= [];

    // 1. check old records
    if (_find(identifier, providers) != null) {
      assert(false, 'duplicated provider: $identifier, chosen: $chosen');
      return await updateProvider(identifier, chosen: chosen);
    }
    // 2. add as new record
    task = _newTask(append: identifier, chosen: chosen);
    bool ok = await task.save(providers);
    if (!ok) {
      logError('failed to add provider: $identifier, chosen: $chosen');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServiceProviderUpdated, this, {
      'action': 'add',
      'ID': identifier,
      'chosen': chosen,
    });
    return true;
  }

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async {
    var task = _newTask();
    var providers = await task.load();
    providers ??= [];

    // 1. check old records
    if (_find(identifier, providers) == null) {
      assert(false, 'provider not found: $identifier, chosen: $chosen');
      return false;
    }
    // 2. update record
    task = _newTask(update: identifier, chosen: chosen);
    bool ok = await task.save(providers);
    if (!ok) {
      logError('failed to update provider: $identifier, chosen: $chosen');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServiceProviderUpdated, this, {
      'action': 'update',
      'ID': identifier,
      'chosen': chosen,
    });
    return true;
  }

  @override
  Future<bool> removeProvider(ID identifier) async {
    var task = _newTask();
    var providers = await task.load();
    providers ??= [];

    // 1. check old records
    if (_find(identifier, providers) == null) {
      assert(false, 'provider not found: $identifier');
      return true;
    }
    // 2. remove record
    task = _newTask(remove: identifier);
    bool ok = await task.save(providers);
    if (!ok) {
      logError('failed to remove provider: $identifier');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServiceProviderUpdated, this, {
      'action': 'remove',
      'ID': identifier,
    });
    return true;
  }

}
