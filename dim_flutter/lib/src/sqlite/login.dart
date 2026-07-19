
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
  Future<List<Pair<LoginCommand, ReliableMessage>>> loadLoginCommandMessages(ID uid) async {
    var cond = SQLConditions.compare('uid', '=', uid.toString());
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC');
  }

  // protected
  Future<bool> deleteLoginCommandMessage(ID uid) async {
    var cond = SQLConditions.compare('uid', '=', uid.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove login command: $uid');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> saveLoginCommandMessage(ID uid, String? terminal, LoginCommand content, ReliableMessage rMsg) async {
    // TODO: save login command with uid + terminal
    logInfo('save login command: $uid, terminal: $terminal');
    // add new record
    String cmd = JSON.encode(content.toMap());
    String msg = JSON.encode(rMsg.toMap());
    List values = [
      uid.toString(),
      cmd,
      msg,
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to save login command: $uid "$terminal" -> $content');
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
    ID uid = _user.withoutTerminal();
    var records = await _table.loadLoginCommandMessages(uid);
    return LoginCommandUtils.trimCommandMessages(records);
  }

  @override
  Future<bool> writeData(List<Pair<LoginCommand, ReliableMessage>> records) async {
    LoginCommand? cmd = _cmd;
    ReliableMessage? msg = _msg;
    if (cmd == null || msg == null) {
      assert(false, 'should not happen: $cmd, $msg');
      return false;
    }
    ID identifier = cmd.identifier;
    ID uid = identifier.withoutTerminal();
    String? terminal = identifier.terminal;
    // TODO: save login command with uid + terminal
    if (records.isNotEmpty) {
      var ok = await _table.deleteLoginCommandMessage(uid);
      if (ok) {
        records.clear();
      } else {
        assert(false, 'failed to clear login commands: $identifier');
        return false;
      }
    }
    var ok = await _table.saveLoginCommandMessage(uid, terminal, cmd, msg);
    if (ok) {
      records.add(Pair(cmd, msg));
      LoginCommandUtils.sortCommandMessages(records);
    }
    return ok;
  }

}

class LoginCommandCache extends DataCache<ID, List<Pair<LoginCommand, ReliableMessage>>> implements LoginDBI {
  LoginCommandCache() : super('login_command');

  final _LoginCommandTable _table = _LoginCommandTable();

  _LoginTask _newTask(ID identifier, {LoginCommand? cmd, ReliableMessage? msg}) =>
      _LoginTask(mutexLock, cachePool, _table, identifier, cmd: cmd, msg: msg);

  @override
  Future<List<Pair<LoginCommand, ReliableMessage>>> getLoginCommandMessages(ID identifier) async {
    var task = _newTask(identifier);
    var array = await task.load();
    return array ?? [];
  }

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async {
    //
    //  1. check old record
    //
    var task = _newTask(identifier);
    var array = await task.load();
    if (array == null) {
      array = [];
    } else {
      // check time
      DateTime? newTime = content.getDateTime('time');
      if (newTime != null) {
        DateTime? oldTime;
        LoginCommand cmd;
        for (Pair<LoginCommand, ReliableMessage> item in array) {
          cmd = item.first;
          oldTime = cmd.getDateTime('time');
          if (oldTime != null && oldTime.isAfter(newTime)) {
            logWarning('ignore expired login: $content');
            return false;
          }
        }
      }
    }
    //
    //  2. save new record
    //
    task = _newTask(identifier, cmd: content, msg: rMsg);
    bool ok = await task.save(array);
    if (!ok) {
      logError('failed to save login command: $identifier -> $content');
      return false;
    }
    //
    //  3. post notification
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLoginCommandUpdated, this, {
      'ID': identifier,
      'cmd': content,
      'msg': rMsg,
    });
    return true;
  }

}
