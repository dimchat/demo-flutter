
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';


///
///  Store login command messages
///
///     file path: '{sdcard}/Android/data/chat.dim.sechat/files/.dim/login.db'
///


class LoginDatabase extends DatabaseConnector {
  LoginDatabase() : super(name: dbName, directory: '.dim', version: dbVersion,
      onCreate: (db, version) async {
        // login command
        await DatabaseConnector.createTable(db, tLogin, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "uid VARCHAR(64) NOT NULL",
          "cmd TEXT NOT NULL",
          "msg TEXT NOT NULL",
        ]);
        await DatabaseConnector.createIndex(db, tLogin,
          name: 'uid_index', columns: ['uid'],
        );
      }, onUpgrade: (db, oldVersion, newVersion) async {
        // TODO:
      });

  static const String dbName = 'login.db';
  static const int dbVersion = 1;

  static const String tLogin         = 't_login';

}


List<Pair<LoginCommand, ReliableMessage>> _sortCommandMessages(List<Pair<LoginCommand, ReliableMessage>> records, ID user) {
  int total = records.length;
  if (total > 1) {
    // 1. Sort records by timestamp descending
    LoginCommandUtils.sortCommandMessages(records);
    // 2. Remove duplicated items by signature
    LoginCommandUtils.tidyCommandMessages(records);
    // TODO: remove expired command(s)
    if (records.length > 8) {
      records.length = 8;
    }
  }
  int count = records.length;
  if (count < total) {
    Log.info('trim $count/$total login command(s) for $user');
  }
  return records;
}


Pair<LoginCommand, ReliableMessage> _extractCommandMessage(ResultSet resultSet, int index) {
  Map? cmd = JSONMap.decode(resultSet.getString('cmd')!);
  Map? msg = JSONMap.decode(resultSet.getString('msg')!);
  return Pair(Command.parse(cmd) as LoginCommand, ReliableMessage.parse(msg)!);
}


class _LoginCommandTable extends DataTableHandler<Pair<LoginCommand, ReliableMessage>> {
  _LoginCommandTable() : super(LoginDatabase(), _extractCommandMessage);

  static const String _table = LoginDatabase.tLogin;
  static const List<String> _selectColumns = ["cmd", "msg"];
  static const List<String> _insertColumns = ["uid", "cmd", "msg"];
  // TODO: add column "terminal"

  // protected
  Future<List<Pair<LoginCommand, ReliableMessage>>> loadLoginCommandMessages(final ID user) async {
    var cond = SQLConditions.compare('uid', '=', user.toString());
    return await select(_table, columns: _selectColumns,
      conditions: cond,
      orderBy: 'id DESC',
    );
  }

  // protected
  Future<bool> deleteLoginCommandMessage(final ID user) async {
    var cond = SQLConditions.compare('uid', '=', user.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove login command: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> saveLoginCommandMessage(final ID user, LoginCommand content, ReliableMessage rMsg) async {
    // TODO: save login command with uid + terminal
    logInfo('save login command: $user, terminal: ${content.terminal}.');
    // add new record
    String cmd = JSON.encode(content.toMap());
    String msg = JSON.encode(rMsg.toMap());
    List values = [
      user.toString(),
      cmd,
      msg,
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to save login command: $user, terminal: ${content.terminal}, $content');
      return false;
    }
    return true;
  }

}

class _LoginTask extends DbTask<ID, List<Pair<LoginCommand, ReliableMessage>>> {
  _LoginTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required LoginCommand? cmd,
    required ReliableMessage? msg,
  }) : _cmd = cmd, _msg = msg;

  final ID _user;

  final LoginCommand? _cmd;
  final ReliableMessage? _msg;

  final _LoginCommandTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<Pair<LoginCommand, ReliableMessage>>?> readData() async {
    var records = await _table.loadLoginCommandMessages(_user);
    return _sortCommandMessages(records, _user);
  }

  @override
  Future<bool> writeData(List<Pair<LoginCommand, ReliableMessage>> records) async {
    LoginCommand? cmd = _cmd;
    ReliableMessage? msg = _msg;
    if (cmd == null || msg == null) {
      assert(false, 'should not happen: $cmd, $msg');
      return false;
    }
    // TODO: save login command with uid + terminal
    if (records.isNotEmpty) {
      var ok = await _table.deleteLoginCommandMessage(_user);
      if (ok) {
        records.clear();
      } else {
        assert(false, 'failed to clear login commands: $_user');
        return false;
      }
    }
    var ok = await _table.saveLoginCommandMessage(_user, cmd, msg);
    if (ok) {
      records.add(Pair(cmd, msg));
      _sortCommandMessages(records, _user);
    }
    return ok;
  }

}

class LoginCommandCache extends DataCache<ID, List<Pair<LoginCommand, ReliableMessage>>> implements LoginDBI {
  LoginCommandCache() : super('login_command');

  final _LoginCommandTable _table = _LoginCommandTable();

  _LoginTask _newTask(ID user, {LoginCommand? cmd, ReliableMessage? msg}) {
    assert(user.terminal == null, 'not a naked id: $user');
    return _LoginTask(mutexLock, cachePool, _table, user, cmd: cmd, msg: msg);
  }

  @override
  Future<List<Pair<LoginCommand, ReliableMessage>>> getLoginCommandMessages(ID user) async {
    var task = _newTask(user);
    return await task.load() ?? [];
  }

  @override
  Future<bool> saveLoginCommandMessage(ID user, LoginCommand content, ReliableMessage rMsg) async {
    assert(content.identifier.isSameAs(user), 'login id not match: $user -> $content');
    //
    //  1. check old record
    //
    var task = _newTask(user);
    var records = await task.load();
    if (records == null) {
      records = [];
    } else {
      // check expired
      DateTime? newTime = content.time;
      if (newTime != null) {
        DateTime? oldTime;
        for (final item in records) {
          oldTime = item.first.time;
          if (oldTime != null && oldTime.isAfter(newTime)) {
            logWarning('ignore expired login command: $content');
            return false;
          }
        }
      }
    }
    //
    //  2. save new record
    //
    task = _newTask(user, cmd: content, msg: rMsg);
    bool ok = await task.save(records);
    if (!ok) {
      logError('failed to save login command: $user -> $content');
      return false;
    }
    //
    //  3. post notification
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLoginCommandUpdated, this, {
      'ID': user,
      'cmd': content,
      'msg': rMsg,
    });
    return true;
  }

}
