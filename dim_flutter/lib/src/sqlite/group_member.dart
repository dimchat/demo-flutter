import 'package:lnc/lnc.dart';

import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'entity.dart';


ID _extractMember(ResultSet resultSet, int index) {
  String? member = resultSet.getString('member');
  return ID.parse(member)!;
}

class _MemberTable extends DataTableHandler<ID> {
  _MemberTable() : super(GroupDatabase(), _extractMember);

  static const String _table = GroupDatabase.tMember;
  static const List<String> _selectColumns = ["member"];
  static const List<String> _insertColumns = ["gid", "member"];

  // protected
  Future<int> updateMembers(List<ID> newMembers, List<ID> oldMembers, ID group) async {
    assert(!identical(newMembers, oldMembers), 'should not be the same object');
    SQLConditions cond;

    // 0. check new members
    if (newMembers.isEmpty) {
      assert(oldMembers.isNotEmpty, 'new members empty??');
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
      if (await delete(_table, conditions: cond) < 0) {
        Log.error('failed to clear members for group: $group');
        return -1;
      }
      Log.warning('members cleared for group: $group');
      return oldMembers.length;
    }
    int count = 0;

    // 1. remove
    for (ID item in oldMembers) {
      if (newMembers.contains(item)) {
        continue;
      }
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
      cond.addCondition(SQLConditions.kAnd,
          left: 'member', comparison: '=', right: item.toString());
      if (await delete(_table, conditions: cond) < 0) {
        Log.error('failed to remove member: $item, group: $group');
        return -1;
      }
      ++count;
    }

    // 2. add
    for (ID item in newMembers) {
      if (oldMembers.contains(item)) {
        continue;
      }
      List values = [group.toString(), item.toString()];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        Log.error('failed to add member: $item, group: $group');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      Log.warning('members not changed: $group');
      return 0;
    }
    Log.info('updated $count member(s) for group: $group');
    return count;
  }

  Future<List<ID>> getMembers(ID group) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

  Future<bool> saveMembers(List<ID> members, ID group) async {
    List<ID> oldMembers = await getMembers(group);
    return await updateMembers(members, oldMembers, group) >= 0;
  }

  Future<bool> addMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    if (oldMembers.contains(member)) {
      Log.warning('member exists: $member, group: $group');
      return true;
    }
    List<ID> newMembers = [...oldMembers, member];
    return await updateMembers(newMembers, oldMembers, group) >= 0;
  }

  Future<bool> removeMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    if (!oldMembers.contains(member)) {
      Log.warning('member not exists: $member, group: $group');
      return true;
    }
    List<ID> newMembers = [...oldMembers];
    newMembers.removeWhere((element) => element == member);
    return await updateMembers(newMembers, oldMembers, group) >= 0;
  }

}

class MemberCache extends _MemberTable {

  final CachePool<ID, List<ID>> _cache = CacheManager().getPool('members');

  @override
  Future<List<ID>> getMembers(ID group) async {
    CachePair<List<ID>>? pair;
    CacheHolder<List<ID>>? holder;
    List<ID>? value;
    double now = Time.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _cache.fetch(group, now: now);
      holder = pair?.holder;
      value = pair?.value;
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
        value = await super.getMembers(group);
        // update cache
        _cache.updateValue(group, value, 3600, now: now);
      }
    } finally {
      unlock();
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveMembers(List<ID> members, ID group) async {
    List<ID> oldMembers = await getMembers(group);
    int cnt = await updateMembers(members, oldMembers, group);
    if (cnt > 0) {
      // clear to reload
      _cache.erase(group);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMembersUpdated, this, {
        'action': 'update',
        'ID': group,
        'group': group,
        'members': members,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> addMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    if (oldMembers.contains(member)) {
      Log.warning('member exists: $member, group: $group');
      return true;
    }
    List<ID> newMembers = [...oldMembers, member];
    int cnt = await updateMembers(newMembers, oldMembers, group);
    if (cnt > 0) {
      // clear to reload
      _cache.erase(group);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
        'ID': group,
        'group': group,
        'member': member,
        'members': newMembers,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> removeMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    if (!oldMembers.contains(member)) {
      Log.warning('member not exists: $member, group: $group');
      return true;
    }
    List<ID> newMembers = [...oldMembers];
    newMembers.removeWhere((element) => element == member);
    int cnt = await updateMembers(newMembers, oldMembers, group);
    if (cnt > 0) {
      // clear to reload
      _cache.erase(group);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'ID': group,
        'group': group,
        'member': member,
        'members': newMembers,
      });
    }
    return cnt >= 0;
  }

}
