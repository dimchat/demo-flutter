import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'entity.dart';


ID _extractMember(ResultSet resultSet, int index) {
  String? member = resultSet.getString('member');
  return ID.parse(member)!;
}

class _MemberTable extends DataTableHandler<ID> {
  _MemberTable() : super(EntityDatabase(), _extractMember);

  static const String _table = EntityDatabase.tMember;
  static const List<String> _selectColumns = ["member"];
  static const List<String> _insertColumns = ["gid", "member"];

  // protected
  Future<int> updateMembers(List<ID> newMembers, List<ID> oldMembers, ID group) async {
    assert(!identical(newMembers, oldMembers), 'should not be the same object');
    SQLConditions cond;

    // 0. check new members
    if (newMembers.isEmpty) {
      assert(oldMembers.isNotEmpty, 'new members empty??');
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.string);
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
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.string);
      cond.addCondition(SQLConditions.kAnd,
          left: 'member', comparison: '=', right: item.string);
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
      List values = [group.string, item.string];
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
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.string);
    return await select(_table, columns: _selectColumns, conditions: cond);
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
    newMembers.remove(member);
    return await updateMembers(newMembers, oldMembers, group) >= 0;
  }

}

class _MemberCache extends _MemberTable {

  final CachePool<ID, List<ID>> _cache = CacheManager().getPool('members');

  @override
  Future<List<ID>> getMembers(ID group) async {
    int now = Time.currentTimeMillis;
    // 1. check memory cache
    CachePair<List<ID>>? pair = _cache.fetch(group, now: now);
    CacheHolder<List<ID>>? holder = pair?.holder;
    List<ID>? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
        _cache.update(group, value: null, life: 128 * 1000, now: now);
      } else {
        if (holder.isAlive(now: now)) {
          // value not exists
          return [];
        }
        // cache expired, wait to reload
        holder.renewal(duration: 128 * 1000, now: now);
      }
      // 2. load from database
      value = await super.getMembers(group);
      // update cache
      _cache.update(group, value: value, life: 3600 * 1000, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveMembers(List<ID> members, ID group) async {
    List<ID> oldMembers = await getMembers(group);
    int cnt = await updateMembers(members, oldMembers, group);
    if (cnt > 0) {
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMembersUpdated, this, {
        'action': 'update',
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
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
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
    newMembers.remove(member);
    int cnt = await updateMembers(newMembers, oldMembers, group);
    if (cnt > 0) {
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'group': group,
        'member': member,
        'members': newMembers,
      });
    }
    return cnt >= 0;
  }

}


class GroupCache implements GroupDBI {
  GroupCache() : _memberTable = _MemberCache();

  final _MemberCache _memberTable;

  @override
  Future<ID?> getFounder({required ID group}) async {
    // TODO: implement getFounder
    Log.error('implement getFounder: $group');
    return null;
  }

  @override
  Future<ID?> getOwner({required ID group}) async {
    // TODO: implement getOwner
    Log.error('implement getOwner: $group');
    return null;
  }

  @override
  Future<List<ID>> getMembers({required ID group}) async =>
      await _memberTable.getMembers(group);

  @override
  Future<bool> saveMembers(List<ID> members, {required ID group}) async =>
      await _memberTable.saveMembers(members, group);

  @override
  Future<bool> addMember(ID member, {required ID group}) async =>
      await _memberTable.addMember(member, group: group);

  @override
  Future<bool> removeMember(ID member, {required ID group}) async =>
      await _memberTable.removeMember(member, group: group);

  @override
  Future<List<ID>> getAssistants({required ID group}) async {
    // TODO: implement getAssistants
    Log.error('implement getAssistants: $group');
    return [];
  }

  @override
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async {
    // TODO: implement saveAssistants
    Log.error('implement saveAssistants: $group, $bots');
    return false;
  }

  @override
  Future<bool> removeGroup({required ID group}) async {
    // TODO: implement removeGroup
    Log.error('implement removeGroup: $group');
    return false;
  }

}
