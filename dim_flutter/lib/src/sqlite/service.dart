import 'package:lnc/lnc.dart';

import '../client/constants.dart';
import 'helper/sqlite.dart';


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
        DatabaseConnector.createTable(db, tSpeed, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "host VARCHAR(128) NOT NULL",  // station IP or domain name
          "port INTEGER NOT NULL",       // station port
          "sid VARCHAR(64) NOT NULL",    // station ID
          "time INTEGER NOT NULL",       // last test time (seconds)
          "duration REAL NOT NULL",      // respond time (seconds)
        ]);
        DatabaseConnector.createIndex(db, tSpeed,
            name: 'ip_index', fields: ['host']);
      },
      onUpgrade: (db, oldVersion, newVersion) {
        // TODO:
      });

  static const String dbName = 'sp.db';
  static const int dbVersion = 1;

  static const String tProvider = 't_provider';
  static const String tStation  = 't_station';
  static const String tSpeed    = 't_speed';

}


typedef _ProviderInfo = Pair<ID, int>;

_ProviderInfo _extractProvider(ResultSet resultSet, int index) {
  String? sp = resultSet.getString('pid');
  int? chosen = resultSet.getInt('chosen');
  return Pair(ID.parse(sp)!, chosen!);
}

class _ProviderTable extends DataTableHandler<_ProviderInfo> implements ProviderDBI {
  _ProviderTable() : super(ServiceProviderDatabase(), _extractProvider);

  static const String _table = ServiceProviderDatabase.tProvider;
  static const List<String> _selectColumns = ["pid", "chosen"];
  static const List<String> _insertColumns = ["pid", "chosen"];

  @override
  Future<List<_ProviderInfo>> getProviders() async {
    SQLConditions cond = SQLConditions.kTrue;
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async {
    List values = [identifier.toString(), chosen];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.toString());
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

  @override
  Future<bool> removeProvider(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.toString());
    return await delete(_table, conditions: cond) > 0;
  }

}

class ProviderCache extends _ProviderTable {

  List<_ProviderInfo>? _caches;

  static int? _find(ID identifier, List<_ProviderInfo> providers) {
    for (_ProviderInfo item in providers) {
      if (item.first == identifier) {
        return item.second;
      }
    }
    return null;
  }

  @override
  Future<List<Pair<ID, int>>> getProviders() async {
    List<_ProviderInfo>? pairs = _caches;
    if (pairs == null) {
      // cache not found, try to load from database
      pairs = await super.getProviders();
      _caches = pairs;
    }
    return pairs;
  }

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async {
    // 1. check old records
    List<_ProviderInfo> providers = await getProviders();
    if (_find(identifier, providers) != null) {
      assert(false, 'duplicated provider: $identifier, chosen: $chosen');
      return updateProvider(identifier, chosen: chosen);
    }
    // 2. add as new record
    if (await super.addProvider(identifier, chosen: chosen)) {
      // clear for reload
      _caches = null;
    } else {
      Log.error('failed to add provider: $identifier, chosen: $chosen');
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
    // 1. check old records
    List<_ProviderInfo> providers = await getProviders();
    if (_find(identifier, providers) == null) {
      assert(false, 'provider not found: $identifier, chosen: $chosen');
      return updateProvider(identifier, chosen: chosen);
    }
    // 2. update record
    if (await super.updateProvider(identifier, chosen: chosen)) {
      // clear for reload
      _caches = null;
    } else {
      Log.error('failed to update provider: $identifier, chosen: $chosen');
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
    // 1. check old records
    List<_ProviderInfo> providers = await getProviders();
    if (_find(identifier, providers) == null) {
      assert(false, 'provider not found: $identifier');
      return true;
    }
    // 2. update record
    if (await super.removeProvider(identifier)) {
      // clear for reload
      _caches = null;
    } else {
      Log.error('failed to remove provider: $identifier');
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
