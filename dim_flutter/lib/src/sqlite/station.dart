
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'service.dart';


StationInfo _extractStation(ResultSet resultSet, int index) {
  String? host = resultSet.getString('host');
  int? port = resultSet.getInt('port');
  String? sp = resultSet.getString('pid');
  int? chosen = resultSet.getInt('chosen');
  ID? provider = ID.parse(sp);
  return StationInfo(null, chosen!, host: host!, port: port!, provider: provider);
}

class _StationTable extends DataTableHandler<StationInfo> {
  _StationTable() : super(ServiceProviderDatabase(), _extractStation);

  static const String _table = ServiceProviderDatabase.tStation;
  static const List<String> _selectColumns = ["pid", "host", "port", "chosen"];
  static const List<String> _insertColumns = ["pid", "host", "port", "chosen"];

  // protected
  Future<List<StationInfo>> loadStations({required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    return await select(_table, distinct: true, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  // protected
  Future<bool> addStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    // add new record
    List values = [
      provider.toString(),
      host,
      port,
      chosen,
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add station: $sid, $host:$port, provider: $provider -> $chosen');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> updateStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    if (sid == null || sid.isBroadcast) {} else {
      // TODO: save station ID?
    }
    if (await update(_table, values: values, conditions: cond) < 1) {
      logError('failed to update station: $sid, $host:$port, provider: $provider -> $chosen');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> removeStation({required String host, required int port, required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove station: $host:$port, provider: $provider');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> removeStations({required ID provider}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove stations of provider: $provider');
      return false;
    }
    return true;
  }

}

class _SrvTask extends DbTask<ID, List<StationInfo>> {
  _SrvTask(super.mutexLock, super.cachePool, this._table, this._provider, {
    required StationInfo? append,
    required StationInfo? update,
    required StationInfo? remove,
  }) : _append = append, _update = update, _remove = remove;

  final ID _provider;
  final StationInfo? _append;
  final StationInfo? _update;
  final StationInfo? _remove;

  final _StationTable _table;

  @override
  ID get cacheKey => _provider;

  @override
  Future<List<StationInfo>?> readData() async {
    return await _table.loadStations(provider: _provider);
  }

  @override
  Future<bool> writeData(List<StationInfo> providers) async {
    // 1. append
    bool ok1 = false;
    StationInfo? append = _append;
    if (append != null) {
      ok1 = await _table.addStation(append.identifier,
        chosen: append.chosen,
        host: append.host,
        port: append.port,
        provider: _provider,
      );
      if (ok1) {
        // clear to reload
        cachePool.erase(cacheKey);
      }
    }
    // 2. update
    bool ok2 = false;
    StationInfo? update = _update;
    if (update != null) {
      ok2 = await _table.updateStation(update.identifier,
        chosen: update.chosen,
        host: update.host,
        port: update.port,
        provider: _provider,
      );
      if (ok2) {
        // clear to reload
        cachePool.erase(cacheKey);
      }
    }
    // 3. remove
    bool ok3 = false;
    StationInfo? remove = _remove;
    if (remove != null) {
      ok3 = await _table.removeStation(
        host: remove.host,
        port: remove.port,
        provider: _provider,
      );
      if (ok3) {
        providers.removeWhere((srv) => srv.identifier == remove.identifier);
      }
    }
    return ok1 || ok2;
  }

}

class StationCache extends DataCache<ID, List<StationInfo>> implements StationDBI {
  StationCache() : super('relay_stations');

  final _StationTable _table = _StationTable();

  _SrvTask _newTask(ID sp, {StationInfo? append, StationInfo? update, StationInfo? remove}) =>
      _SrvTask(mutexLock, cachePool, _table, sp,
          append: append,
          update: update,
          remove: remove,
      );

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
    var task = _newTask(provider);
    var providers = await task.load();
    return providers ?? [];
  }

  @override
  Future<bool> addStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    var task = _newTask(provider);
    var stations = await task.load();
    stations ??= [];

    // 1. check old records
    if (_find(host, port, stations) != null) {
      logWarning('duplicated station: $host, $port, provider: $provider, chosen: $chosen');
      return await updateStation(sid, chosen: chosen, host: host, port: port, provider: provider);
    }
    // 2. insert as new record
    var info = StationInfo(sid, chosen, host: host, port: port, provider: provider);
    task = _newTask(provider, append: info);
    bool ok = await task.save(stations);

    if (!ok) {
      logError('failed to add station: $host, $port, provider: $provider, chosen: $chosen');
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
  Future<bool> updateStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    var task = _newTask(provider);
    var stations = await task.load();
    stations ??= [];

    // 1. check old records
    if (_find(host, port, stations) == null) {
      logWarning('station not found: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 2. update record
    var info = StationInfo(sid, chosen, host: host, port: port, provider: provider);
    task = _newTask(provider, update: info);
    bool ok = await task.save(stations);
    if (!ok) {
      logError('failed to update station: $host, $port, provider: $provider, chosen: $chosen');
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
  Future<bool> removeStation({
    required String host, required int port, required ID provider
  }) async {
    var task = _newTask(provider);
    var stations = await task.load();
    stations ??= [];

    // 1. check old records
    if (_find(host, port, stations) == null) {
      logWarning('station not found: $host, $port, provider: $provider');
      return true;
    }
    // 2. remove record
    var info = StationInfo(Station.ANY, 0, host: host, port: port, provider: provider);
    task = _newTask(provider, remove: info);
    bool ok = await task.save(stations);
    if (!ok) {
      logError('failed to remove station: $host, $port, provider: $provider');
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
    bool ok;
    await mutexLock.acquire();
    try {
      ok = await _table.removeStations(provider: provider);
      if (ok) {
        cachePool.purge();
      }
    } finally {
      mutexLock.release();
    }
    if (!ok) {
      logError('failed to remove stations for provider: $provider');
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
