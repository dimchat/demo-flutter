import 'helper/sqlite.dart';


///
///  Store login command messages
///
///     file path: '/sdcard/chat.dim.sechat/.dkd/login.db'
///


class LoginCommandTable implements LoginDBI {

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


class ProviderTable implements ProviderDBI {

  @override
  Future<List<Pair<ID, int>>> getProviders() async {
    // TODO: implement getProviders
    Log.error('implement getProviders');
    return [];
  }

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async {
    // TODO: implement addProvider
    Log.error('implement addProvider: $identifier');
    return false;
  }

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async {
    // TODO: implement updateProvider
    Log.error('implement updateProvider: $identifier');
    return false;
  }

  @override
  Future<bool> removeProvider(ID identifier) async {
    // TODO: implement removeProvider
    Log.error('implement removeProvider: $identifier');
    return false;
  }

}


class StationTable implements StationDBI {

  @override
  Future<List<Pair<String, int>>> getStations({required ID provider}) async {
    // TODO: implement getStations
    Log.error('implement getStations: $provider');
    return [];
  }

  @override
  Future<bool> addStation(String host, int port, {required ID provider, int chosen = 0}) async {
    // TODO: implement addStation
    Log.error('implement addStation: $host, $port');
    return false;
  }

  @override
  Future<bool> updateStation(String host, int port, {required ID provider, int chosen = 0}) async {
    // TODO: implement updateStation
    Log.error('implement updateStation: $host, $port');
    return false;
  }

  @override
  Future<bool> removeStation(String host, int port, {required ID provider}) async {
    // TODO: implement removeStation
    Log.error('implement removeStation: $host, $port');
    return false;
  }

  @override
  Future<bool> removeStations({required ID provider}) async {
    // TODO: implement removeStations
    Log.error('implement removeStations: $provider');
    return false;
  }

}
