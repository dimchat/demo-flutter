
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


ID _extractAdmin(ResultSet resultSet, int index) {
  String? admin = resultSet.getString('admin');
  return ID.parse(admin)!;
}

class _AdminTable extends DataTableHandler<ID> {
  _AdminTable() : super(GroupDatabase(), _extractAdmin);

  static const String _table = GroupDatabase.tAdmin;
  static const List<String> _selectColumns = ["admin"];
  static const List<String> _insertColumns = ["gid", "admin"];

  // protected
  Future<int> updateAdministrators(List<ID> newAdmins, List<ID> oldAdmins, ID group) async {
    assert(!identical(newAdmins, oldAdmins), 'should not be the same object');
    SQLConditions cond;

    // 0. check new admins
    if (newAdmins.isEmpty) {
      // assert(oldAdmins.isNotEmpty, 'new administrators empty??');
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to clear administrators for group: $group');
        return -1;
      }
      logWarning('administrators cleared for group: $group');
      return oldAdmins.length;
    }
    int count = 0;

    // 1. remove
    for (ID item in oldAdmins) {
      if (newAdmins.contains(item)) {
        continue;
      }
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
      cond.addCondition(SQLConditions.kAnd,
          left: 'admin', comparison: '=', right: item.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to remove administrator: $item, group: $group');
        return -1;
      }
      ++count;
    }

    // 2. add
    for (ID item in newAdmins) {
      if (oldAdmins.contains(item)) {
        continue;
      }
      List values = [group.toString(), item.toString()];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        logError('failed to add administrator: $item, group: $group');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      logWarning('administrators not changed: $group');
      return 0;
    }
    logInfo('updated $count administrator(s) for group: $group');
    return count;
  }

  // protected
  Future<List<ID>> getAdministrators(ID group) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

}

class _AdminTask extends DbTask<ID, List<ID>> {
  _AdminTask(super.mutexLock, super.cachePool, this._table, this._group, {
    required List<ID>? oldAdmins,
  }) : _oldAdmins = oldAdmins;

  final ID _group;

  final List<ID>? _oldAdmins;

  final _AdminTable _table;

  @override
  ID get cacheKey => _group;

  @override
  Future<List<ID>?> readData() async {
    return await _table.getAdministrators(_group);
  }

  @override
  Future<bool> writeData(List<ID> newAdmins) async {
    List<ID>? oldAdmins = _oldAdmins;
    if (oldAdmins == null) {
      assert(false, 'should not happen: $_group');
      return false;
    }
    int count = await _table.updateAdministrators(newAdmins, oldAdmins, _group);
    return count > 0;
  }

}

class AdminCache extends DataCache<ID, List<ID>> {
  AdminCache() : super('group_admins');

  final _AdminTable _table = _AdminTable();

  _AdminTask _newTask(ID group, {List<ID>? oldAdmins}) =>
      _AdminTask(mutexLock, cachePool, _table, group, oldAdmins: oldAdmins);

  Future<List<ID>> getAdministrators(ID group) async {
    var task = _newTask(group);
    var contacts = await task.load();
    return contacts ?? [];
  }

  Future<bool> _updateAdmins(List<ID> newAdmins, List<ID> oldAdmins, {required ID group}) async {
    var task = _newTask(group, oldAdmins: oldAdmins);
    return await task.save(newAdmins);
  }

  Future<bool> saveAdministrators(List<ID> newAdmins, ID group) async {
    // save new admins
    var oldAdmins = await getAdministrators(group);
    var ok = await _updateAdmins(newAdmins, oldAdmins, group: group);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'update',
        'ID': group,
        'group': group,
        'administrators': newAdmins,
      });
    }
    return ok;
  }

  Future<bool> addAdministrator(ID admin, {required ID group}) async {
    List<ID> oldAdmins = await getAdministrators(group);
    if (oldAdmins.contains(admin)) {
      logWarning('admin exists: $admin, group: $group');
      return true;
    }
    List<ID> newAdmins = [...oldAdmins, admin];
    var ok = await _updateAdmins(newAdmins, oldAdmins, group: group);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'add',
        'ID': group,
        'group': group,
        'administrator': admin,
        'administrators': newAdmins,
      });
    }
    return ok;
  }

  Future<bool> removeAdministrator(ID admin, {required ID group}) async {
    List<ID> oldAdmins = await getAdministrators(group);
    if (!oldAdmins.contains(admin)) {
      logWarning('administrator not exists: $admin, group: $group');
      return true;
    }
    List<ID> newAdmins = [...oldAdmins];
    newAdmins.removeWhere((element) => element == admin);
    var ok = await _updateAdmins(newAdmins, oldAdmins, group: group);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'remove',
        'ID': group,
        'group': group,
        'administrator': admin,
        'administrators': newAdmins,
      });
    }
    return ok;
  }

}
