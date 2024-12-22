
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';

import 'entity.dart';


ID _extractUser(ResultSet resultSet, int index) {
  String? user = resultSet.getString('uid');
  return ID.parse(user)!;
}

class _UserTable extends DataTableHandler<ID> implements UserDBI {
  _UserTable() : super(EntityDatabase(), _extractUser);

  static const String _table = EntityDatabase.tLocalUser;
  static const List<String> _selectColumns = ["uid"];
  static const List<String> _insertColumns = ["uid", "chosen"];

  // protected
  Future<int> updateUsers(List<ID> newUsers, List<ID> oldUsers) async {
    assert(!identical(newUsers, oldUsers), 'should not be the same object');
    SQLConditions cond;

    // 0. check new users
    if (newUsers.isEmpty) {
      assert(oldUsers.isNotEmpty, 'new users empty??');
      SQLConditions cond = SQLConditions.kTrue;
      if (await delete(_table, conditions: cond) < 0) {
        Log.error('failed to clear local users');
        return -1;
      }
      Log.warning('local users cleared');
      return oldUsers.length;
    }
    int count = 0;

    // 1. remove
    for (ID item in oldUsers) {
      if (newUsers.contains(item)) {
        continue;
      }
      cond = SQLConditions(left: 'uid', comparison: '=', right: item.toString());
      if (await delete(_table, conditions: cond) < 0) {
        Log.error('failed to remove local user: $item');
        return -1;
      }
      ++count;
    }

    // 2. check current user
    if (count < oldUsers.length && newUsers.indexOf(oldUsers[0]) > 0) {
      // 1. some old user(s) not removed,
      // 2. current user changed, and it's still in the new list;
      // so,
      //    we need to erase chosen flags for it
      Map<String, dynamic> values = {'chosen': 0};
      SQLConditions cond = SQLConditions.kTrue;
      if (await update(_table, values: values, conditions: cond) < 0) {
        Log.error('failed to update local users');
        return -1;
      }
      ++count;
    }
    ID current = newUsers[0];
    int pos = oldUsers.indexOf(current);
    if (pos < 0) {
      // current user changed, and it's not in the new list
      // insert it with 'chosen = 1'
      List values = [current.toString(), 1];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        Log.error('failed to add current user: $current');
        return -1;
      }
      ++count;
    } else if (pos > 1) {
      // current user changed, and it's in the new list,
      // (of cause it would not be the first one),
      // update it: 'chosen = 1'
      Map<String, dynamic> values = {'chosen': 1};
      SQLConditions cond;
      cond = SQLConditions(left: 'uid', comparison: '=', right: current.toString());
      if (await update(_table, values: values, conditions: cond) < 0) {
        Log.error('failed to update current user: $current');
        return -1;
      }
      ++count;
    }

    // 3. add other new users
    for (int index = 1; index < newUsers.length; ++index) {
      ID item = newUsers[index];
      if (oldUsers.contains(item)) {
        continue;
      }
      // add other user with chosen flag = 0
      List values = [item.toString(), 0];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        Log.error('failed to add local user: $item');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      Log.warning('local users not changed: $newUsers');
      return 0;
    }
    Log.info('local users updated: $newUsers');
    return count;
  }

  @override
  Future<List<ID>> getLocalUsers() async {
    SQLConditions cond = SQLConditions.kTrue;
    return await select(_table, distinct: true, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  @override
  Future<bool> saveLocalUsers(List<ID> users) async {
    List<ID> oldUsers = await getLocalUsers();
    return await updateUsers(users, oldUsers) >= 0;
  }

  Future<bool> addUser(ID user) async {
    List<ID> oldUsers = await getLocalUsers();
    if (oldUsers.contains(user)) {
      Log.warning('user exists: $user');
      return true;
    }
    List<ID> newUsers = [...oldUsers, user];
    return await updateUsers(newUsers, oldUsers) >= 0;
  }

  Future<bool> removeUser(ID user) async {
    List<ID> oldUsers = await getLocalUsers();
    if (!oldUsers.contains(user)) {
      Log.warning('user not exists: $user');
      return true;
    }
    List<ID> newUsers = [...oldUsers];
    newUsers.removeWhere((element) => element == user);
    return await updateUsers(newUsers, oldUsers) >= 0;
  }

  Future<bool> setCurrentUser(ID user) async {
    List<ID> oldUsers = await getLocalUsers();
    int pos = oldUsers.indexOf(user);
    if (pos == 0) {
      Log.warning('current user not changed: $user');
      return true;
    }
    List<ID> newUsers = [...oldUsers];
    if (pos > 0) {
      newUsers.removeAt(pos);
    }
    newUsers.insert(0, user);
    return await updateUsers(newUsers, oldUsers) >= 0;
  }

  Future<ID?> getCurrentUser() async {
    List<ID> localUsers = await getLocalUsers();
    return localUsers.isEmpty ? null : localUsers[0];
  }

}

class UserCache extends _UserTable {

  List<ID>? _caches;

  @override
  Future<List<ID>> getLocalUsers() async {
    List<ID>? users;
    await lock();
    try {
      users = _caches;
      if (users == null) {
        // cache not found, try to load from database
        users = await super.getLocalUsers();
        // add to cache
        _caches = users;
      }
    } finally {
      unlock();
    }
    return users;
  }

  @override
  Future<bool> saveLocalUsers(List<ID> users) async {
    List<ID> oldUsers = await getLocalUsers();
    int cnt = await updateUsers(users, oldUsers);
    if (cnt > 0) {
      // clear to reload
      _caches = null;
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'update',
        'users': users,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> addUser(ID user) async {
    List<ID> oldUsers = await getLocalUsers();
    if (oldUsers.contains(user)) {
      Log.warning('user exists: $user');
      return true;
    }
    List<ID> newUsers = [...oldUsers, user];
    int cnt = await updateUsers(newUsers, oldUsers);
    if (cnt > 0) {
      // clear to reload
      _caches = null;
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'add',
        'user': user,
        'users': newUsers,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> removeUser(ID user) async {
    List<ID> oldUsers = await getLocalUsers();
    if (!oldUsers.contains(user)) {
      Log.warning('user not exists: $user');
      return true;
    }
    List<ID> newUsers = [...oldUsers];
    newUsers.removeWhere((element) => element == user);
    int cnt = await updateUsers(newUsers, oldUsers);
    if (cnt > 0) {
      // clear to reload
      _caches = null;
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'remove',
        'user': user,
        'users': newUsers,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> setCurrentUser(ID user) async {
    List<ID> oldUsers = await getLocalUsers();
    int pos = oldUsers.indexOf(user);
    if (pos == 0) {
      Log.warning('current user not changed: $user');
      return true;
    }
    List<ID> newUsers = [...oldUsers];
    if (pos > 0) {
      newUsers.removeAt(pos);
    }
    newUsers.insert(0, user);
    int cnt = await updateUsers(newUsers, oldUsers);
    if (cnt > 0) {
      // clear to reload
      _caches = null;
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'set',
        'user': user,
        'users': newUsers,
      });
    }
    return cnt >= 0;
  }

}
