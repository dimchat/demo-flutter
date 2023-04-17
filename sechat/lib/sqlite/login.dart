import '../client/constants.dart';
import '../client/filesys/paths.dart';
import '../models/local.dart';
import 'helper/sqlite.dart';


///
///  Store login command messages
///
///     file path: '{sdcard}/Android/data/chat.dim.sechat/files/.dim/login.db'
///


class LoginDatabase extends DatabaseConnector {
  LoginDatabase() : super(name: dbName, directory: '.dim', version: dbVersion,
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

  static const String dbName = 'login.db';
  static const int dbVersion = 1;

  static const String tLogin         = 't_login';

  /// returns: '{caches}/.dim/login.db'
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
  LoginCommandTable() : super(LoginDatabase(), _extractCommandMessage);

  static const String _table = LoginDatabase.tLogin;
  static const List<String> _selectColumns = ["cmd", "msg"];
  static const List<String> _insertColumns = ["uid", "cmd", "msg"];

  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.string);
    List<Pair<LoginCommand, ReliableMessage>> array = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);
    // first record only
    return array.isEmpty ? const Pair(null, null) : array[0];
  }

  Future<bool> deleteLoginCommandMessage(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.string);
    return await delete(_table, conditions: cond) > 0;
  }

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async {
    String cmd = JSON.encode(content.dictionary);
    String msg = JSON.encode(rMsg.dictionary);
    List values = [identifier.string, cmd, msg];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class LoginCommandCache extends LoginCommandTable {
  LoginCommandCache() {
    _cache = CacheManager().getPool('login_command');
  }

  late final CachePool<ID, Pair<LoginCommand?, ReliableMessage?>> _cache;

  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async {
    int now = Time.currentTimeMillis;
    // 1. check memory cache
    CachePair<Pair<LoginCommand?, ReliableMessage?>>? pair;
    pair = _cache.fetch(identifier, now: now);
    CacheHolder<Pair<LoginCommand?, ReliableMessage?>>? holder = pair?.holder;
    Pair<LoginCommand?, ReliableMessage?>? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
        _cache.update(identifier, value: null, life: 128 * 1000, now: now);
      } else {
        if (holder.isAlive(now: now)) {
          // value not exists
          return const Pair(null, null);
        }
        // cache expired, wait to reload
        holder.renewal(duration: 128 * 1000, now: now);
      }
      // 2. load from database
      value = await super.getLoginCommandMessage(identifier);
      // update cache
      _cache.update(identifier, value: value, life: 3600 * 1000, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async {
    // 1. check old record
    LoginCommand? old = (await getLoginCommandMessage(identifier)).first;
    if (old != null && _isCommandExpired(content, old)) {
      Log.warning('expired command: $identifier');
      return false;
    }
    // 2. clear old records
    if (old != null) {
      if (await deleteLoginCommandMessage(identifier)) {
        Log.debug('old login command cleared: $identifier');
      } else {
        Log.error('failed to clear login command: $identifier');
        return false;
      }
    }
    // 3. add new record
    if (await super.saveLoginCommandMessage(identifier, content, rMsg)) {
      //
    } else {
      Log.error('failed to save login command: $identifier');
      return false;
    }
    // 4. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLoginCommandUpdated, this, {
      'ID': identifier,
      'cmd': content,
      'msg': rMsg,
    });
    return true;
  }

}

bool _isCommandExpired(LoginCommand newOne, LoginCommand oldOne) {
  DateTime? oldTime = oldOne.time;
  if (oldTime == null) {
    Log.warning('old time not found: ${oldOne.identifier}');
    return false;
  }
  DateTime? newTime = newOne.time;
  if (newTime == null) {
    Log.warning('new time not found: ${newOne.identifier}');
    return false;
  }
  return !newTime.isAfter(oldTime);
}
