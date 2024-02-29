import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';

import '../common/constants.dart';
import '../common/platform.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';
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
    if (DevicePlatform.isWeb) {
      return await super.path;
    }
    String? root = await LocalStorage().cachesDirectory;
    if (root == null) {
      Log.error('failed to get directory for login.db');
      return null;
    }
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


class _LoginCommandTable extends DataTableHandler<Pair<LoginCommand, ReliableMessage>> implements LoginDBI {
  _LoginCommandTable() : super(LoginDatabase(), _extractCommandMessage);

  static const String _table = LoginDatabase.tLogin;
  static const List<String> _selectColumns = ["cmd", "msg"];
  static const List<String> _insertColumns = ["uid", "cmd", "msg"];

  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.toString());
    List<Pair<LoginCommand, ReliableMessage>> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    return array.isEmpty ? const Pair(null, null) : array[0];
  }

  Future<bool> deleteLoginCommandMessage(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.toString());
    return await delete(_table, conditions: cond) >= 0;
  }

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async {
    String cmd = JSON.encode(content.toMap());
    String msg = JSON.encode(rMsg.toMap());
    List values = [identifier.toString(), cmd, msg];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class LoginCommandCache extends _LoginCommandTable {
  LoginCommandCache() {
    _cache = CacheManager().getPool('login_command');
  }

  late final CachePool<ID, Pair<LoginCommand?, ReliableMessage?>> _cache;

  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async {
    CachePair<Pair<LoginCommand?, ReliableMessage?>>? pair;
    CacheHolder<Pair<LoginCommand?, ReliableMessage?>>? holder;
    Pair<LoginCommand?, ReliableMessage?>? value;
    double now = Time.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _cache.fetch(identifier, now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value == null) {
        if (holder == null) {
          // not load yet, wait to load
        } else if (holder.isAlive(now: now)) {
          // value not exists
          return const Pair(null, null);
        } else {
          // cache expired, wait to reload
          holder.renewal(128, now: now);
        }
        // 2. load from database
        value = await super.getLoginCommandMessage(identifier);
        // update cache
        _cache.updateValue(identifier, value, 3600, now: now);
      }
    } finally {
      unlock();
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async {
    // 1. check old record
    LoginCommand? old = (await getLoginCommandMessage(identifier)).first;
    if (DocumentHelper.isBefore(old?.time, content.time)) {
      Log.warning('expired command: $identifier');
      return false;
    }
    // 2. clear old records
    if (old != null) {
      if (await deleteLoginCommandMessage(identifier)) {
        Log.debug('old login command cleared: $identifier');
        // clear to reload
        _cache.erase(identifier);
      } else {
        Log.error('failed to clear login command: $identifier');
        return false;
      }
    }
    // 3. add new record
    if (await super.saveLoginCommandMessage(identifier, content, rMsg)) {
      // clear to reload
      _cache.erase(identifier);
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
