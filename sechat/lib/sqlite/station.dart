import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'service.dart';


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
