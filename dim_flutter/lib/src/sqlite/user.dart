
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


ID _extractUser(ResultSet resultSet, int index) {
  String? user = resultSet.getString('uid');
  return ID.parse(user)!;
}

class _UserTable extends DataTableHandler<ID> {
  _UserTable() : super(EntityDatabase(), _extractUser);

  static const String _table = EntityDatabase.tLocalUser;
  static const List<String> _selectColumns = ["uid"];
  static const List<String> _insertColumns = ["uid", "chosen"];

  // protected
  Future<bool> removeUser(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove local user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addUser(ID user, bool chosen) async {
    // add other user with chosen flag = 0
    List values = [
      user.toString(),
      chosen ? 1 : 0
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add local user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> updateUser(ID user, bool chosen) async {
    Map<String, dynamic> values = {
      'chosen': chosen ? 1 : 0
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    if (await update(_table, values: values, conditions: cond) < 0) {
      logError('failed to update local user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> updateUsers(bool chosen) async {
    Map<String, dynamic> values = {
      'chosen': chosen ? 1 : 0
    };
    SQLConditions cond = SQLConditions.kTrue;
    if (await update(_table, values: values, conditions: cond) < 0) {
      logError('failed to update local users');
      return false;
    }
    return true;
  }

  // protected
  Future<List<ID>> loadUsers() async {
    SQLConditions cond = SQLConditions.kTrue;
    return await select(_table, distinct: true, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

}

class _UsrTask extends DbTask<String, List<ID>> {
  _UsrTask(super.mutexLock, super.cachePool, this._table, {
    required ID? append,
    required ID? remove,
    required bool? chosen,
  }) : _append = append, _remove = remove, _chosen = chosen;

  final ID? _append;
  final ID? _remove;
  final bool? _chosen;

  final _UserTable _table;

  @override
  String get cacheKey => 'local_users';

  @override
  Future<List<ID>?> readData() async {
    return await _table.loadUsers();
  }

  @override
  Future<bool> writeData(List<ID> localUsers) async {
    bool chosen = _chosen == true;
    // 1. add
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addUser(append, chosen);
      if (ok1) {
        localUsers.add(append);
      }
    }
    // 2. remove
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok2 = await _table.removeUser(remove);
      if (ok2) {
        localUsers.remove(remove);
      }
    }
    return ok1 || ok2;
  }

}

class UserCache extends DataCache<String, List<ID>> implements UserDBI {
  UserCache() : super('local_users');

  final _UserTable _table = _UserTable();

  _UsrTask _newTask({ID? append, ID? remove, bool? chosen}) =>
      _UsrTask(mutexLock, cachePool, _table, append: append, remove: remove, chosen: chosen);

  @override
  Future<List<ID>> getLocalUsers() async {
    var task = _newTask();
    var localUsers = await task.load();
    return localUsers ?? [];
  }

  @override
  Future<bool> saveLocalUsers(List<ID> newUsers) async {
    var task = _newTask();
    var localUsers = await task.load();
    localUsers ??= [];

    var oldUsers = [...localUsers];
    int count = 0;
    // 1. remove
    for (ID item in oldUsers) {
      if (newUsers.contains(item)) {
        continue;
      }
      task = _newTask(remove: item);
      if (await task.save(localUsers)) {
        ++count;
      } else {
        logError('failed to remove user: $item');
        return false;
      }
    }
    // 2. add
    for (ID item in newUsers) {
      if (oldUsers.contains(item)) {
        continue;
      }
      task = _newTask(append: item);
      if (await task.save(localUsers)) {
        ++count;
      } else {
        logError('failed to add user: $item');
        return false;
      }
    }

    if (count == 0) {
      logWarning('users not changed: $oldUsers');
    } else {
      logInfo('updated $count user(s)');
    }

    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
      'action': 'update',
      'users': newUsers,
    });
    return true;
  }

  Future<bool> addUser(ID user) async {
    var task = _newTask();
    var localUsers = await task.load();
    if (localUsers == null) {
      localUsers = [];
    } else if (localUsers.contains(user)) {
      logWarning('user exists: $user');
      return true;
    }
    task = _newTask(append: user);
    var ok = await task.save(localUsers);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'add',
        'user': user,
        'users': localUsers,
      });
    }
    return ok;
  }

  Future<bool> removeUser(ID user) async {
    var task = _newTask();
    var localUsers = await task.load();
    if (localUsers == null) {
      logError('failed to get local users');
      return false;
    } else if (localUsers.contains(user)) {
      // found
    } else {
      logWarning('user not exists: $user');
      return true;
    }
    task = _newTask(remove: user);
    var ok = await task.save(localUsers);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'remove',
        'user': user,
        'users': localUsers,
      });
    }
    return ok;
  }

  Future<bool> setCurrentUser(ID user) async {
    // load users
    var task = _newTask();
    var localUsers = await task.load();
    int pos;
    if (localUsers == null) {
      localUsers = [];
      pos = -1;
    } else {
      pos = localUsers.indexOf(user);
    }

    bool ok;
    // check users
    if (localUsers.isEmpty) {
      //
      //  add first user
      //
      task = _newTask(append: user, chosen: true);
      ok = await task.save(localUsers);
    } else if (pos == 0) {
      //
      //  current user not changed
      //
      return true;
    } else if (pos > 0) {
      //
      //  change current user
      //
      await _table.updateUsers(false);
      ok = await _table.updateUser(user, true);
      // shift to front
      localUsers.removeAt(pos);
      localUsers.insert(0, user);
    } else {
      //
      //  add new user
      //
      await _table.updateUsers(false);
      task = _newTask(append: user, chosen: true);
      ok = await task.save(localUsers);
      // shift to front
      localUsers.remove(user);
      localUsers.insert(0, user);
    }
    if (!ok) {
      logError('failed to set current user');
      return false;
    }

    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
      'action': 'set',
      'user': user,
      'users': localUsers,
    });
    return true;
  }

  Future<ID?> getCurrentUser() async {
    List<ID> localUsers = await getLocalUsers();
    return localUsers.isEmpty ? null : localUsers[0];
  }

}
