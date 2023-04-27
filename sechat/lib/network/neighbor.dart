import 'package:dim_client/dim_client.dart';

import '../client/shared.dart';
import '../models/config.dart';
import '../models/station.dart';

/// get nearest station, chosen provider first
Future<StationInfo?> getNeighborStation() async {
  GlobalVariable shared = GlobalVariable();
  SessionDBI database = shared.sdb;
  try {
    await _updateStations(database);
  } catch (e) {
    Log.error('failed to update stations: $e');
  }
  StationInfo? fast;
  // check service provider
  List<Pair<ID, int>> providers = await database.getProviders();
  List<_StationInfo> stations;
  List<StationInfo> candidates;
  for (var item in providers) {
    stations = await database.getStations(provider: item.first);
    if (stations.isEmpty) {
      Log.error('no station in provider: $item');
      continue;
    }
    Log.info('got ${stations.length} station(s) in provider: $item');
    // check first station after sorted
    candidates = await StationInfo.fromList(stations);
    candidates = StationInfo.sortStations(candidates);
    if (fast == null) {
      // take the first one whatever,
      // if it's tested before, then return it
      // else, check the other providers
      fast = candidates.first;
      if (fast.responseTime != null) {
        Log.info('chose the fast station: $fast, provider: $item');
        break;
      }
    } else if (candidates.first.responseTime != null) {
      // there is a candidate from another provider before,
      // but it's not tested yet,
      // if this provider's first station is tested, then return it
      fast = candidates.first;
      Log.info('chose the fast station: $fast, provider: $item');
      break;
    }
  }
  return fast;
}

Future<bool> _updateStations(SessionDBI database) async {
  // 1. get stations from config
  Config config = Config();
  Map info = await config.info;
  ID? pid = ID.parse(info['ID']);
  List? stations = info['stations'];
  if (pid == null || stations == null || stations.isEmpty) {
    assert(false, 'config error: $info');
    return false;
  }

  // 2. check service provider
  List<Pair<ID, int>> providers = await database.getProviders();
  if (providers.isEmpty) {
    // database empty, add first provider
    if (await database.addProvider(pid, chosen: 1)) {
      Log.warning('first provider added: $pid');
    } else {
      Log.error('failed to add provider: $pid');
      return false;
    }
  } else {
    // check with providers from database
    bool exists = false;
    for (var item in providers) {
      if (item.first == pid) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      if (await database.addProvider(pid, chosen: 0)) {
        Log.warning('provider added: $pid');
      } else {
        Log.error('failed to add provider: $pid');
        return false;
      }
    }
  }

  // 3. check neighbor stations
  List<_StationInfo> currentStations = await database.getStations(provider: pid);
  String host;
  int port;
  for (Map item in stations) {
    host = item['host'];
    port = item['port'];
    if (_contains(host, port, currentStations)) {
      Log.debug('station exists: $item');
    } else if (await database.addStation(host, port, provider: pid)) {
      Log.warning('station added: $item, $pid');
    } else {
      Log.error('failed to add station: $item');
      return false;
    }
  }

  // OK
  return true;
}

bool _contains(String host, int port, List<_StationInfo> stations) {
  Pair<String, int> srv = Pair(host, port);
  for (var item in stations) {
    if (item.first == srv) {
      return true;
    }
  }
  return false;
}

typedef _StationInfo = Triplet<Pair<String, int>, ID, int>;
