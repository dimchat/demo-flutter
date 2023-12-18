import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../common/dbi/network.dart';
import '../client/shared.dart';

class NeighborInfo {
  NeighborInfo(this.host, this.port, {required this.provider, required this.chosen});

  final String host;
  final int port;
  final ID provider;
  int chosen;

  ID? identifier;
  DateTime? testTime;    // last test time
  double? responseTime;  // average response time in seconds

  String? name;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz host="$host" port=$port pid="$provider" chosen=$chosen>\n'
        '\tID: $identifier, name: $name, speed: $responseTime @ $testTime\n'
        '</$clazz>';
  }

  Future<void> reloadData() async {
    GlobalVariable shared = GlobalVariable();
    // TODO: get average speed
    List<SpeedRecord> records = await shared.database.getSpeeds(host, port);
    if (records.isEmpty) {
      // identifier = null;
      testTime = null;
      responseTime = null;
    } else {
      // Triplet<Pair<String, int>, ID, Pair<DateTime, double>>
      var speed = records.first;
      identifier = speed.second;
      testTime = speed.third.first;
      responseTime = speed.third.second;
    }
    // get name
    ID? sid = identifier;
    if (sid != null) {
      name = await shared.facebook.getName(sid);
    }
  }

  /// create stations info from t_station
  static Future<List<NeighborInfo>> fromList(List<StationInfo> records) async {
    List<NeighborInfo> array = [];
    for (var item in records) {
      array.add(await NeighborInfo.newStation(item));
    }
    return array;
  }

  /// create station info from t_station
  static Future<NeighborInfo> newStation(StationInfo record) async =>
      await _StationManager().newStation(
          record.host, record.port,
          provider: record.provider ?? ProviderInfo.kGSP, chosen: record.chosen
      );

  /// get stations for speed tested
  static List<NeighborInfo> getStations(String host, int port, {ID? provider}) =>
      _StationManager().getStations(host, port, provider: provider);

  /// sort stations with response time (chosen first)
  static List<NeighborInfo> sortStations(List<NeighborInfo> stations) {
    // sort with response time
    stations.sort((a, b) {
      double? art = a.responseTime;
      double? brt = b.responseTime;
      if (art == 0) {
        art = null;
        Log.error('response time error: $a');
      }
      if (brt == 0) {
        brt = null;
        Log.error('response time error: $b');
      }
      assert(art != 0 && brt != 0, 'response time error: $a, $b');
      // filter error stations
      if (art != null && art < 0) {
        // station a cannot connect, check station b
        return brt != null && brt < 0 ? 0 : 1;
      } else if (brt != null && brt < 0) {
        // station a can connect, station b cannot connect,
        // so station a first.
        return -1;
      }
      // all not error, chosen first
      if (a.chosen > b.chosen) {
        // station a is chosen, station a first
        return -1;
      } else if (a.chosen < b.chosen) {
        // station b is chosen, station b first
        return 1;
      }
      // same level, fast first
      if (art == null || art == 0) {
        // station has no test record, check station b
        return brt == null || brt == 0 ? 0 : 1;
      } else if (brt == null || brt == 0) {
        // station a has record, station b has no record,
        // so station a first
        return -1;
      } else if (art < brt) {
        // station a is faster than station b,
        // so station a first
        return -1;
      } else if (art > brt) {
        // station a is slower than station b,
        // so station b first
        return 1;
      } else {
        // same
        return 0;
      }
    });
    return stations;
  }

}

class _StationManager {
  factory _StationManager() => _instance;
  static final _StationManager _instance = _StationManager._internal();
  _StationManager._internal();

  // host => stations
  final Map<String, List<NeighborInfo>> _stationMap = {};

  Future<NeighborInfo> newStation(String host, int port,
      {required ID provider, required int chosen}) async {
    List<NeighborInfo>? stations = _stationMap[host];
    if (stations == null) {
      // new host
      stations = [];
      _stationMap[host] = stations;
    } else {
      // check for duplicated record
      for (NeighborInfo srv in stations) {
        if (srv.port == port && srv.provider == provider) {
          assert(srv.host == host, 'station error: $srv');
          // assert(srv.chosen == chosen, 'station error: srv');
          return srv;
        }
      }
    }
    NeighborInfo info = NeighborInfo(host, port, provider: provider, chosen: chosen);
    stations.add(info);
    await info.reloadData();
    return info;
  }

  List<NeighborInfo> getStations(String host, int port, {ID? provider}) {
    List<NeighborInfo>? stations = _stationMap[host];
    if (stations == null) {
      return [];
    }
    List<NeighborInfo> array = [];
    for (NeighborInfo srv in stations) {
      if (srv.port != port) {
        continue;
      } else if (provider != null && srv.provider != provider) {
        continue;
      }
      assert(srv.host == host, 'station error: $srv');
      array.add(srv);
    }
    return array;
  }

}
