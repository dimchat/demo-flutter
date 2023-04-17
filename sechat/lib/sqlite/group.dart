import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'entity.dart';


ID _extractMember(ResultSet resultSet, int index) {
  String? member = resultSet.getString('member');
  return ID.parse(member)!;
}

class _MemberDB extends DataTableHandler<ID> {
  _MemberDB() : super(EntityDatabase(), _extractMember);

  static const String _table = EntityDatabase.tMember;
  static const List<String> _selectColumns = ["member"];
  static const List<String> _insertColumns = ["gid", "member"];

  final Map<ID, List<ID>> _caches = {};

  Future<int> _updateMembers(List<ID> newMembers, List<ID> oldMembers, ID group) async {
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
      _caches.remove(group);
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
    _caches[group] = newMembers;
    return count;
  }

  Future<List<ID>> getMembers(ID group) async {
    List<ID>? members = _caches[group];
    if (members == null) {
      // cache not found, try to load from database
      SQLConditions cond;
      cond = SQLConditions(left: 'gid', comparison: '=', right: group.string);
      members = await select(_table, columns: _selectColumns, conditions: cond);
      // add to cache
      _caches[group] = members;
    }
    return members;
  }

  Future<bool> saveMembers(List<ID> members, ID group) async {
    List<ID> oldMembers = await getMembers(group);
    int cnt = await _updateMembers(members, oldMembers, group);
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

  Future<bool> addMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    List<ID> newMembers = [...oldMembers, member];
    int cnt = await _updateMembers(newMembers, oldMembers, group);
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

  Future<bool> removeMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    List<ID> newMembers = [...oldMembers];
    newMembers.remove(member);
    int cnt = await _updateMembers(newMembers, oldMembers, group);
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


class GroupTable implements GroupDBI {
  GroupTable() : _memberTable = _MemberDB();

  final _MemberDB _memberTable;

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
