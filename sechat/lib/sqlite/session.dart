import '../client/dbi/session.dart';
import 'helper/sqlite.dart';


///
///  Store login command messages
///
///     file path: '/sdcard/chat.dim.sechat/.dkd/login.db'
///


class LoginCommandDB implements LoginTable {

  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async {
    // TODO: implement getLoginCommandMessage
    Log.error('implement getLoginCommandMessage: $identifier');
    return const Pair(null, null);
  }

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async {
    // TODO: implement saveLoginCommandMessage
    Log.error('implement saveLoginCommandMessage: $identifier');
    return false;
  }

}


///
///  Store service providers, stations
///
///     file path: '/data/data/chat.dim.sechat/databases/sp.db'
///


class ProviderDB implements ProviderTable {

  @override
  Future<bool> addProvider(ID identifier, {String? name, String? url, int chosen = 0}) async {
    // TODO: implement addProvider
    Log.error('implement addProvider: $identifier');
    return false;
  }

  @override
  Future<List<ProviderInfo>> getProviders() async {
    // TODO: implement getProviders
    Log.error('implement getProviders');
    return [];
  }

  @override
  Future<bool> removeProvider(ID identifier) async {
    // TODO: implement removeProvider
    Log.error('implement removeProvider: $identifier');
    return false;
  }

  @override
  Future<bool> updateProvider(ID identifier, {String? name, String? url, int chosen = 0}) async {
    // TODO: implement updateProvider
    Log.error('implement updateProvider: $identifier');
    return false;
  }

}


class StationDB implements StationTable {

  @override
  Future<bool> addNeighbor(String host, int port, [ID? station]) async {
    // TODO: implement addNeighbor
    Log.error('implement addNeighbor: $host, $port, $station');
    return false;
  }

  @override
  Future<bool> addStation(String host, int port, {ID? station, String? name, int chosen = 0, ID? provider}) async {
    // TODO: implement addStation
    Log.error('implement addStation: $host, $port');
    return false;
  }

  @override
  Future<Set<Triplet<String, int, ID?>>> allNeighbors() async {
    // TODO: implement allNeighbors
    Log.error('implement allNeighbors');
    return {};
  }

  @override
  Future<bool> chooseStation(String host, int port, {ID? provider}) async {
    // TODO: implement chooseStation
    Log.error('implement chooseStation: $host, $port');
    return false;
  }

  @override
  Future<ID?> getNeighbor(String host, int port) async {
    // TODO: implement getNeighbor
    Log.error('implement getNeighbor: $host, $port');
    return null;
  }

  @override
  Future<List<StationInfo>> getStations(ID? provider) async {
    // TODO: implement getStations
    Log.error('implement getStations: $provider');
    return [];
  }

  @override
  Future<bool> removeNeighbor(String host, int port) async {
    // TODO: implement removeNeighbor
    Log.error('implement removeNeighbor: $host, $port');
    return false;
  }

  @override
  Future<bool> removeStation(String host, int port, {ID? provider}) async {
    // TODO: implement removeStation
    Log.error('implement removeStation: $host, $port');
    return false;
  }

  @override
  Future<bool> removeStations(ID provider) async {
    // TODO: implement removeStations
    Log.error('implement removeStations: $provider');
    return false;
  }

  @override
  Future<bool> updateStation(String host, int port,
      {required ID? station, required String? name, required int chosen, required ID? provider}) async {
    // TODO: implement updateStation
    Log.error('implement updateStation: $host, $port');
    return false;
  }

}
