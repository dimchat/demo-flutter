import '../client/filesys/paths.dart';
import '../models/local.dart';
import 'helper/sqlite.dart';


///
///  Store login command messages
///
///     file path: '{sdcard}/Android/data/chat.dim.sechat/files/.dim/session.db'
///


class SessionDatabase extends DatabaseConnector {
  SessionDatabase() : super(name: dbName, directory: '.dim', version: dbVersion,
      onCreate: (db, version) {
        // login command
        DatabaseConnector.createTable(db, tLogin, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "uid VARCHAR(64) NOT NULL",
          "cmd TEXT NOT NULL",
          "msg TEXT NOT NULL",
        ]);
        DatabaseConnector.createIndex(db, tLogin,
            name: 'uid_index', fields: ['uid']);
      }, onUpgrade: (db, oldVersion, newVersion) {
        // TODO:
      });

  static const String dbName = 'session.db';
  static const int dbVersion = 1;

  static const String tLogin         = 't_login';

  /// returns: '{caches}/.dim/session.db'
  @override
  Future<String?> get path async {
    String root = await LocalStorage().cachesDirectory;
    String dir = Paths.append(root, directory);
    if (await Paths.mkdirs(dir)) {
      // make sure parent directory exists
      Log.debug('created: $dir');
    } else {
      Log.error('failed to create directory: $dir');
      return null;
    }
    Log.debug('external database: $name in $dir');
    return Paths.append(dir, name);
  }

}


Pair<LoginCommand, ReliableMessage> _extractCommandMessage(ResultSet resultSet, int index) {
  Map? cmd = JSONMap.decode(resultSet.getString('cmd')!);
  Map? msg = JSONMap.decode(resultSet.getString('msg')!);
  return Pair(Command.parse(cmd) as LoginCommand, ReliableMessage.parse(msg)!);
}


class LoginCommandTable extends DataTableHandler<Pair<LoginCommand, ReliableMessage>> implements LoginDBI {
  LoginCommandTable() : super(SessionDatabase(), _extractCommandMessage);

  static const String _table = SessionDatabase.tLogin;
  static const List<String> _selectColumns = ["cmd", "msg"];
  static const List<String> _insertColumns = ["uid", "cmd", "msg"];

  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.string);
    List<Pair<LoginCommand, ReliableMessage>> array = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);
    // return first record only
    Pair<LoginCommand, ReliableMessage>? res = array.isEmpty ? null : array[0];
    return Pair(res?.first, res?.second);
  }

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.string);
    if (await delete(_table, conditions: cond) < 0) {
      Log.error('DB error! failed to clear login command: $identifier');
      return false;
    }
    String cmd = JSON.encode(content.dictionary);
    String msg = JSON.encode(rMsg.dictionary);
    List values = [identifier.string, cmd, msg];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}


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

  @override
  Future<List<Pair<ID, int>>> getProviders() async {
    SQLConditions cond = SQLConditions.kTrue;
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async {
    List values = [identifier.string, chosen];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.string);
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    return await update(_table, values: values, conditions: cond) > 0;
  }

  @override
  Future<bool> removeProvider(ID identifier) async {
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

  @override
  Future<List<Triplet<Pair<String, int>, ID, int>>> getStations({required ID provider}) async {
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
