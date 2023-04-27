import 'package:dim_client/dim_client.dart';

import '../client/shared.dart';

class StationInfo {
  StationInfo(this.host, this.port, {required this.provider, required this.chosen});

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
    var records = await shared.database.getSpeeds(host, port);
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
  static Future<List<StationInfo>> fromList(List<Triplet<Pair<String, int>, ID, int>> records) async {
    List<StationInfo> array = [];
    for (var item in records) {
      array.add(await StationInfo.newStation(item));
    }
    return array;
  }

  /// create station info from t_station
  static Future<StationInfo> newStation(Triplet<Pair<String, int>, ID, int> record) async =>
      await _StationManager().newStation(
          record.first.first, record.first.second,
          provider: record.second, chosen: record.third
      );

  /// get stations for speed tested
  static List<StationInfo> getStations(String host, int port, {ID? provider}) =>
      _StationManager().getStations(host, port, provider: provider);

  /// sort stations with response time (chosen first)
  static List<StationInfo> sortStations(List<StationInfo> stations) {
    stations.sort((a, b) {
      // chosen first
      if (a.chosen > b.chosen) {
        return -1;
      } else if (a.chosen < b.chosen) {
        return 1;
      }
      // sort with response time
      double? art = a.responseTime;
      double? brt = b.responseTime;
      if (art == null) {
        return brt == null ? 0 : 1;
      } else if (brt == null) {
        return -1;
      } else if (art > brt) {
        return 1;
      } else if (art < brt) {
        return -1;
      } else {
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
  final Map<String, List<StationInfo>> _stationMap = {};

  Future<StationInfo> newStation(String host, int port,
      {required ID provider, required int chosen}) async {
    List<StationInfo>? stations = _stationMap[host];
    if (stations == null) {
      // new host
      stations = [];
      _stationMap[host] = stations;
    } else {
      // check for duplicated record
      for (StationInfo srv in stations) {
        if (srv.port == port && srv.provider == provider) {
          assert(srv.host == host, 'station error: $srv');
          // assert(srv.chosen == chosen, 'station error: srv');
          return srv;
        }
      }
    }
    StationInfo info = StationInfo(host, port, provider: provider, chosen: chosen);
    stations.add(info);
    await info.reloadData();
    return info;
  }

  List<StationInfo> getStations(String host, int port, {ID? provider}) {
    List<StationInfo>? stations = _stationMap[host];
    if (stations == null) {
      return [];
    }
    List<StationInfo> array = [];
    for (StationInfo srv in stations) {
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
