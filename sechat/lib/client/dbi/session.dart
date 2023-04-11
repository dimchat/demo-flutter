import 'package:dim_client/dim_client.dart';

abstract class LoginTable implements LoginDBI {

}

class ProviderInfo {
  ProviderInfo(this.identifier, {this.name, this.url, this.chosen = 0});

  ID identifier;
  String? name;
  String? url;

  int chosen;
}

abstract class ProviderTable {

  ///  Get all providers
  ///
  /// @return provider list
  Future<List<ProviderInfo>> getProviders();

  ///  Add provider info
  ///
  /// @param identifier - sp ID
  /// @param name       - sp name
  /// @param url        - entrance URL
  /// @param chosen     - whether current sp
  /// @return false on failed
  Future<bool> addProvider(ID identifier, {String? name, String? url, int chosen = 0});

  ///  Update provider info
  ///
  /// @param identifier - sp ID
  /// @param name       - sp name
  /// @param url        - entrance URL
  /// @param chosen     - whether current sp
  /// @return false on failed
  Future<bool> updateProvider(ID identifier, {String? name, String? url, int chosen = 0});

  ///  Remove provider info
  ///
  /// @param identifier - sp ID
  /// @return false on failed
  Future<bool> removeProvider(ID identifier);

}

class StationInfo {
  StationInfo(this.host, this.port, {this.identifier, this.name, this.chosen = 0});

  ID? identifier;
  String? name;

  String host;
  int port;

  int chosen;
}

abstract class StationTable implements ProviderDBI {

  ///  Get all stations of this sp
  ///
  /// @param provider - sp ID
  /// @return station list
  Future<List<StationInfo>> getStations(ID? provider);

  ///  Add station info with sp ID
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param station  - station ID
  /// @param name     - station name
  /// @param chosen   - whether current station
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> addStation(String host, int port,
      {ID? station, String? name, int chosen = 0, ID? provider});

  ///  Update station info
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param station  - station ID
  /// @param name     - station name
  /// @param chosen   - whether current station
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> updateStation(String host, int port,
      {required ID? station, required String? name, required int chosen, required ID? provider});

  ///  Set this station as current station
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> chooseStation(String host, int port, {ID? provider});

  ///  Remove this station
  ///
  /// @param host     - station IP
  /// @param port     - station port
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> removeStation(String host, int port, {ID? provider});

  ///  Remove all station of the sp
  ///
  /// @param provider - sp ID
  /// @return false on failed
  Future<bool> removeStations(ID provider);

}
