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


Pair<ID, int> _extractProvider(ResultSet resultSet, int index) {
  String? sp = resultSet.getString('pid');
  int? chosen = resultSet.getInt('chosen');
  return Pair(ID.parse(sp)!, chosen!);
}


class ProviderTable extends DataTableHandler<Pair<ID, int>> implements ProviderDBI {
  ProviderTable() : super(ServiceProviderDatabase(), _extractProvider);

  static const String _table = ServiceProviderDatabase.tProvider;
  static const List<String> _selectColumns = ["pid", "chosen"];
  static const List<String> _insertColumns = ["pid", "chosen"];

  List<Pair<ID, int>>? _caches;

  @override
  Future<List<Pair<ID, int>>> getProviders() async {
    List<Pair<ID, int>>? pairs = _caches;
    if (pairs == null) {
      SQLConditions cond = SQLConditions.kTrue;
      pairs = await select(_table, columns: _selectColumns,
          conditions: cond, orderBy: 'chosen DESC');
      _caches = pairs;
    }
    return pairs;
  }

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async {
    // clear for reload
    _caches = null;
    // add new record
    List values = [identifier.string, chosen];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async {
    // clear for reload
    _caches = null;
    // update record
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.string);
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

  @override
  Future<bool> removeProvider(ID identifier) async {
    // clear for reload
    _caches = null;
    // remove record
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.string);
    return await delete(_table, conditions: cond) > 0;
  }

}


Triplet<Pair<String, int>, ID, int> _extractStation(ResultSet resultSet, int index) {
  String? host = resultSet.getString('host');
  int? port = resultSet.getInt('port');
  String? sp = resultSet.getString('pid');
  int? chosen = resultSet.getInt('chosen');
  return Triplet(Pair(host!, port!), ID.parse(sp)!, chosen!);
}


class StationTable extends DataTableHandler<Triplet<Pair<String, int>, ID, int>> implements StationDBI {
  StationTable() : super(ServiceProviderDatabase(), _extractStation);

  static const String _table = ServiceProviderDatabase.tStation;
  static const List<String> _selectColumns = ["pid", "host", "port", "chosen"];
  static const List<String> _insertColumns = ["pid", "host", "port", "chosen"];

  /// pid => [<<host, port>, pid, chosen>]
  final Map<ID, List<dynamic>> _caches = {};

  @override
  Future<List<Triplet<Pair<String, int>, ID, int>>> getStations({required ID provider}) async {
    dynamic stations = _caches[provider];
    if (stations == null) {
      // cache not found, try to load from database
      SQLConditions cond;
      cond = SQLConditions(left: 'pid', comparison: '=', right: provider.string);
      stations = await select(_table, columns: _selectColumns,
          conditions: cond, orderBy: 'chosen DESC');
      // add to cache
      _caches[provider] = stations;
    }
    return stations;
  }

  @override
  Future<bool> addStation(String host, int port, {required ID provider, int chosen = 0}) async {
    // clear for reload
    _caches.remove(provider);
    // add record
    List values = [provider.string, host, port, chosen];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateStation(String host, int port, {required ID provider, int chosen = 0}) async {
    // clear for reload
    _caches.remove(provider);
    // update record
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
    // clear for reload
    _caches.remove(provider);
    // remove record
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.string);
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    return await delete(_table, conditions: cond) > 0;
  }

  @override
  Future<bool> removeStations({required ID provider}) async {
    // clear for reload
    _caches.remove(provider);
    // remove records
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.string);
    return await delete(_table, conditions: cond) > 0;
  }

}
