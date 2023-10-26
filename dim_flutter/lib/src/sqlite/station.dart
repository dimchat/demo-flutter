import 'package:lnc/lnc.dart';

import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'service.dart';


StationInfo _extractStation(ResultSet resultSet, int index) {
  String? host = resultSet.getString('host');
  int? port = resultSet.getInt('port');
  String? sp = resultSet.getString('pid');
  int? chosen = resultSet.getInt('chosen');
  ID? provider = ID.parse(sp);
  return StationInfo(null, chosen!, host: host!, port: port!, provider: provider);
}

class _StationTable extends DataTableHandler<StationInfo> implements StationDBI {
  _StationTable() : super(ServiceProviderDatabase(), _extractStation);

  static const String _table = ServiceProviderDatabase.tStation;
  static const List<String> _selectColumns = ["pid", "host", "port", "chosen"];
  static const List<String> _insertColumns = ["pid", "host", "port", "chosen"];

  @override
  Future<List<StationInfo>> allStations({required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  @override
  Future<bool> addStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider}) async {
    List values = [provider.toString(), host, port, chosen];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

  @override
  Future<bool> removeStation({required String host, required int port, required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    return await delete(_table, conditions: cond) > 0;
  }

  @override
  Future<bool> removeStations({required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    return await delete(_table, conditions: cond) > 0;
  }

}

class StationCache extends _StationTable {

  /// pid => [<<host, port>, pid, chosen>]
  final CachePool<ID, List<StationInfo>> _cache = CacheManager().getPool('stations');

  static StationInfo? _find(String host, int port, List<StationInfo> stations) {
    for (StationInfo item in stations) {
      if (item.host == host && item.port == port) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<StationInfo>> allStations({required ID provider}) async {
    CachePair<List<StationInfo>>? pair;
    CacheHolder<List<StationInfo>>? holder;
    List<StationInfo>? value;
    double now = Time.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _cache.fetch(provider, now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value == null) {
        if (holder == null) {
          // not load yet, wait to load
        } else if (holder.isAlive(now: now)) {
          // value not exists
          return [];
        } else {
          // cache expired, wait to reload
          holder.renewal(128, now: now);
        }
        // 2. load from database
        value = await super.allStations(provider: provider);
        // update cache
        _cache.updateValue(provider, value, 3600, now: now);
      }
    } finally {
      unlock();
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> addStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider}) async {
    // 1. check old records
    List<StationInfo> stations = await allStations(provider: provider);
    if (_find(host, port, stations) != null) {
      Log.warning('duplicated station: $host, $port, provider: $provider, chosen: $chosen');
      return await updateStation(sid, host: host, port: port, provider: provider);
    }
    // 2. insert as new record
    if (await super.addStation(sid, host: host, port: port, provider: provider)) {
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
  Future<bool> updateStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider}) async {
    // 1. check old records
    List<StationInfo> stations = await allStations(provider: provider);
    if (_find(host, port, stations) == null) {
      Log.warning('station not found: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 2. update record
    if (await super.updateStation(sid, host: host, port: port, provider: provider)) {
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
  Future<bool> removeStation({required String host, required int port, required ID provider}) async {
    // 1. check old records
    List<StationInfo> stations = await allStations(provider: provider);
    if (_find(host, port, stations) == null) {
      Log.warning('station not found: $host, $port, provider: $provider');
      return false;
    }
    // 2. remove record
    if (await super.removeStation(host: host, port: port, provider: provider)) {
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
