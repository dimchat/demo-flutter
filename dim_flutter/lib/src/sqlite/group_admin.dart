
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
  Future<bool> removeAdmin(ID admin, {required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'admin', comparison: '=', right: admin.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove administrator: $admin, group: $group');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addAdmin(ID admin, {required ID group}) async {
    // add new record
    List values = [
      group.toString(),
      admin.toString(),
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add administrator: $admin, group: $group');
      return false;
    }
    return true;
  }

  // protected
  Future<List<ID>> loadAdministrators(ID group) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

}

class _AdminTask extends DbTask<ID, List<ID>> {
  _AdminTask(super.mutexLock, super.cachePool, this._table, this._group, {
    required ID? append,
    required ID? remove,
  }) : _append = append, _remove = remove;

  final ID _group;

  final ID? _append;
  final ID? _remove;

  final _AdminTable _table;

  @override
  ID get cacheKey => _group;

  @override
  Future<List<ID>?> readData() async {
    return await _table.loadAdministrators(_group);
  }

  @override
  Future<bool> writeData(List<ID> admins) async {
    // 1. add
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addAdmin(append, group: _group);
      if (ok1) {
        admins.add(append);
      }
    }
    // 2. remove
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok2 = await _table.removeAdmin(remove, group: _group);
      if (ok2) {
        admins.remove(remove);
      }
    }
    return ok1 || ok2;
  }

}

class AdminCache extends DataCache<ID, List<ID>> {
  AdminCache() : super('group_admins');

  final _AdminTable _table = _AdminTable();

  _AdminTask _newTask(ID group, {ID? append, ID? remove}) =>
      _AdminTask(mutexLock, cachePool, _table, group, append: append, remove: remove);

  Future<List<ID>> getAdministrators(ID group) async {
    var task = _newTask(group);
    var contacts = await task.load();
    return contacts ?? [];
  }

  Future<bool> saveAdministrators(List<ID> newAdmins, ID group) async {
    var task = _newTask(group);
    var allAdmins = await task.load();
    allAdmins ??= [];

    var oldAdmins = [...allAdmins];
    int count = 0;
    // 1. remove
    for (ID item in oldAdmins) {
      if (newAdmins.contains(item)) {
        continue;
      }
      task = _newTask(group, remove: item);
      if (await task.save(allAdmins)) {
        ++count;
      } else {
        logError('failed to remove admin: $item, group: $group');
        return false;
      }
    }
    // 2. add
    for (ID item in newAdmins) {
      if (oldAdmins.contains(item)) {
        continue;
      }
      task = _newTask(group, append: item);
      if (await task.save(allAdmins)) {
        ++count;
      } else {
        logError('failed to add admin: $item, group: $group');
        return false;
      }
    }

    if (count == 0) {
      logWarning('admins not changed: $group');
    } else {
      logInfo('updated $count admin(s) for group: $group');
    }

    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
      'action': 'update',
      'ID': group,
      'group': group,
      'administrators': newAdmins,
    });
    return true;
  }

  Future<bool> addAdministrator(ID admin, {required ID group}) async {
    var task = _newTask(group);
    var allAdmins = await task.load();
    if (allAdmins == null) {
      allAdmins = [];
    } else if (allAdmins.contains(admin)) {
      logWarning('admin exists: $admin, group: $group');
      return true;
    }
    task = _newTask(group, append: admin);
    var ok = await task.save(allAdmins);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'add',
        'ID': group,
        'group': group,
        'administrator': admin,
        'administrators': allAdmins,
      });
    }
    return ok;
  }

  Future<bool> removeAdministrator(ID admin, {required ID group}) async {
    var task = _newTask(group);
    var allAdmins = await task.load();
    if (allAdmins == null) {
      logError('failed to get admins');
      return false;
    } else if (allAdmins.contains(admin)) {
      // found
    } else {
      logWarning('admin not exists: $admin, group: $group');
      return true;
    }
    task = _newTask(group, remove: admin);
    var ok = await task.save(allAdmins);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'remove',
        'ID': group,
        'group': group,
        'administrator': admin,
        'administrators': allAdmins,
      });
    }
    return ok;
  }

}
