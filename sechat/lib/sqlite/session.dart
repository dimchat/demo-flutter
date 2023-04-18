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
          "pid VARCHAR(64) NOT NULL",
          "host VARCHAR(128) NOT NULL",  // IP or domain name
          "port INTEGER NOT NULL",
          "chosen INTEGER",
        ]);
        DatabaseConnector.createIndex(db, tStation,
            name: 'sp_id_index', fields: ['pid']);
        // access speed
        DatabaseConnector.createTable(db, tSpeed, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "host VARCHAR(128) NOT NULL",  // IP or domain name
          "port INTEGER NOT NULL",
          "time INTEGER NOT NULL",       // last test time
          "duration INTEGER NOT NULL",   // respond time
        ]);
        DatabaseConnector.createIndex(db, tSpeed,
            name: 'ip_index', fields: ['host']);
      },
      onUpgrade: (db, oldVersion, newVersion) {
        // TODO:
      });

  static const String dbName = 'mkm.db';
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
    List values = [identifier.string, chosen];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.string);
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

  @override
  Future<bool> removeProvider(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.string);
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


typedef _StationInfo = Triplet<Pair<String, int>, ID, int>;

_StationInfo _extractStation(ResultSet resultSet, int index) {
  String? host = resultSet.getString('host');
  int? port = resultSet.getInt('port');
  String? sp = resultSet.getString('pid');
  int? chosen = resultSet.getInt('chosen');
  return Triplet(Pair(host!, port!), ID.parse(sp)!, chosen!);
}

class _StationTable extends DataTableHandler<_StationInfo> implements StationDBI {
  _StationTable() : super(ServiceProviderDatabase(), _extractStation);

  static const String _table = ServiceProviderDatabase.tStation;
  static const List<String> _selectColumns = ["pid", "host", "port", "chosen"];
  static const List<String> _insertColumns = ["pid", "host", "port", "chosen"];

  @override
  Future<List<_StationInfo>> getStations({required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.string);
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  @override
  Future<bool> addStation(String host, int port, {required ID provider, int chosen = 0}) async {
    List values = [provider.string, host, port, chosen];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateStation(String host, int port, {required ID provider, int chosen = 0}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.string);
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

  @override
  Future<bool> removeStation(String host, int port, {required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.string);
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    return await delete(_table, conditions: cond) > 0;
  }

  @override
  Future<bool> removeStations({required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.string);
    return await delete(_table, conditions: cond) > 0;
  }

}

class StationCache extends _StationTable {

  /// pid => [<<host, port>, pid, chosen>]
  final CachePool<ID, List<_StationInfo>> _cache = CacheManager().getPool('stations');

  static _StationInfo? _find(String host, int port, List<_StationInfo> stations) {
    for (_StationInfo item in stations) {
      if (item.first.first == host && item.first.second == port) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<Triplet<Pair<String, int>, ID, int>>> getStations({required ID provider}) async {
    int now = Time.currentTimeMillis;
    // 1. check memory cache
    CachePair<List<_StationInfo>>? pair = _cache.fetch(provider, now: now);
    CacheHolder<List<_StationInfo>>? holder = pair?.holder;
    List<_StationInfo>? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
        _cache.update(provider, value: null, life: 128 * 1000, now: now);
      } else {
        if (holder.isAlive(now: now)) {
          // value not exists
          return [];
        }
        // cache expired, wait to reload
        holder.renewal(duration: 128 * 1000, now: now);
      }
      // 2. load from database
      value = await super.getStations(provider: provider);
      // update cache
      _cache.update(provider, value: value, life: 3600 * 1000, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> addStation(String host, int port, {required ID provider, int chosen = 0}) async {
    // 1. check old records
    List<_StationInfo> stations = await getStations(provider: provider);
    if (_find(host, port, stations) != null) {
      Log.warning('duplicated station: $host, $port, provider: $provider, chosen: $chosen');
      return await updateStation(host, port, provider: provider, chosen: chosen);
    }
    // 2. insert as new record
    if (await super.addStation(host, port, provider: provider, chosen: chosen)) {
      // clear for reload
      _cache.erase(provider);
    } else {
      Log.error('failed to add station: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'add',
      'host': host,
      'port': port,
      'provider': provider,
      'chosen': chosen,
    });
    return true;
  }

  @override
  Future<bool> updateStation(String host, int port, {required ID provider, int chosen = 0}) async {
    // 1. check old records
    List<_StationInfo> stations = await getStations(provider: provider);
    if (_find(host, port, stations) == null) {
      Log.warning('station not found: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 2. update record
    if (await super.updateStation(host, port, provider: provider, chosen: chosen)) {
      // clear for reload
      _cache.erase(provider);
    } else {
      Log.error('failed to update station: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'update',
      'host': host,
      'port': port,
      'provider': provider,
      'chosen': chosen,
    });
    return true;
  }

  @override
  Future<bool> removeStation(String host, int port, {required ID provider}) async {
    // 1. check old records
    List<_StationInfo> stations = await getStations(provider: provider);
    if (_find(host, port, stations) == null) {
      Log.warning('station not found: $host, $port, provider: $provider');
      return false;
    }
    // 2. remove record
    if (await super.removeStation(host, port, provider: provider)) {
      // clear for reload
      _cache.erase(provider);
    } else {
      Log.error('failed to remove station: $host, $port, provider: $provider');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'remove',
      'host': host,
      'port': port,
      'provider': provider,
    });
    return true;
  }

  @override
  Future<bool> removeStations({required ID provider}) async {
    if (await super.removeStations(provider: provider)) {
      // clear for reload
      _cache.erase(provider);
    } else {
      Log.error('failed to remove stations for provider: $provider');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'removeAll',
      'provider': provider,
    });
    return true;
  }

}
