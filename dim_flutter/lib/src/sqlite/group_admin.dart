import 'package:lnc/lnc.dart';

import '../client/constants.dart';
import 'helper/sqlite.dart';
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
      assert(oldAdmins.isNotEmpty, 'new administrators empty??');
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
      if (await delete(_table, conditions: cond) < 0) {
        Log.error('failed to clear administrators for group: $group');
        return -1;
      }
      Log.warning('administrators cleared for group: $group');
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
        Log.error('failed to remove administrator: $item, group: $group');
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
        Log.error('failed to add administrator: $item, group: $group');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      Log.warning('administrators not changed: $group');
      return 0;
    }
    Log.info('updated $count administrator(s) for group: $group');
    return count;
  }

  Future<List<ID>> getAdministrators(ID group) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

  Future<bool> saveAdministrators(List<ID> admins, ID group) async {
    List<ID> oldAdmins = await getAdministrators(group);
    return await updateAdministrators(admins, oldAdmins, group) >= 0;
  }

  Future<bool> addAdministrator(ID admin, {required ID group}) async {
    List<ID> oldAdmins = await getAdministrators(group);
    if (oldAdmins.contains(admin)) {
      Log.warning('admin exists: $admin, group: $group');
      return true;
    }
    List<ID> newAdmins = [...oldAdmins, admin];
    return await updateAdministrators(newAdmins, oldAdmins, group) >= 0;
  }

  Future<bool> removeAdministrator(ID admin, {required ID group}) async {
    List<ID> oldAdmins = await getAdministrators(group);
    if (!oldAdmins.contains(admin)) {
      Log.warning('admin not exists: $admin, group: $group');
      return true;
    }
    List<ID> newAdmins = [...oldAdmins];
    newAdmins.removeWhere((element) => element == admin);
    return await updateAdministrators(newAdmins, oldAdmins, group) >= 0;
  }

}

class AdminCache extends _AdminTable {

  final CachePool<ID, List<ID>> _cache = CacheManager().getPool('administrators');

  @override
  Future<List<ID>> getAdministrators(ID group) async {
    double now = Time.currentTimeSeconds;
    // 1. check memory cache
    CachePair<List<ID>>? pair = _cache.fetch(group, now: now);
    if (pair == null) {
      // maybe another thread is trying to load data,
      // so wait a while to check it again.
      await randomWait();
      pair = _cache.fetch(group, now: now);
    }
    CacheHolder<List<ID>>? holder = pair?.holder;
    List<ID>? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
      } else if (holder.isAlive(now: now)) {
        // value not exists
        return [];
      } else {
        // cache expired, wait to reload
        holder.renewal(128, now: now);
      }
      // 2. load from database
      value = await super.getAdministrators(group);
      // update cache
      _cache.updateValue(group, value, 3600, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveAdministrators(List<ID> admins, ID group) async {
    List<ID> oldAdmins = await getAdministrators(group);
    int cnt = await updateAdministrators(admins, oldAdmins, group);
    if (cnt > 0) {
      // clear to reload
      _cache.erase(group);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'update',
        'ID': group,
        'group': group,
        'administrators': admins,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> addAdministrator(ID admin, {required ID group}) async {
    List<ID> oldAdmins = await getAdministrators(group);
    if (oldAdmins.contains(admin)) {
      Log.warning('admin exists: $admin, group: $group');
      return true;
    }
    List<ID> newAdmins = [...oldAdmins, admin];
    int cnt = await updateAdministrators(newAdmins, oldAdmins, group);
    if (cnt > 0) {
      // clear to reload
      _cache.erase(group);
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
    return cnt >= 0;
  }

  @override
  Future<bool> removeAdministrator(ID admin, {required ID group}) async {
    List<ID> oldAdmins = await getAdministrators(group);
    if (!oldAdmins.contains(admin)) {
      Log.warning('administrator not exists: $admin, group: $group');
      return true;
    }
    List<ID> newAdmins = [...oldAdmins];
    newAdmins.removeWhere((element) => element == admin);
    int cnt = await updateAdministrators(newAdmins, oldAdmins, group);
    if (cnt > 0) {
      // clear to reload
      _cache.erase(group);
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
    return cnt >= 0;
  }

}
