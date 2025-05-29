
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

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
        logError('failed to clear members for group: $group');
        return -1;
      }
      logWarning('members cleared for group: $group');
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
        logError('failed to remove member: $item, group: $group');
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
        logError('failed to add member: $item, group: $group');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      logWarning('members not changed: $group');
      return 0;
    }
    logInfo('updated $count member(s) for group: $group');
    return count;
  }

  // protected
  Future<List<ID>> getMembers(ID group) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

}

class _MemTask extends DbTask<ID, List<ID>> {
  _MemTask(super.mutexLock, super.cachePool, this._table, this._group, {
    required List<ID>? oldMembers,
  }) : _oldMembers = oldMembers;

  final ID _group;

  final List<ID>? _oldMembers;

  final _MemberTable _table;

  @override
  ID get cacheKey => _group;

  @override
  Future<List<ID>?> readData() async {
    return await _table.getMembers(_group);
  }

  @override
  Future<bool> writeData(List<ID> newMembers) async {
    List<ID>? oldMembers = _oldMembers;
    if (oldMembers == null) {
      assert(false, 'should not happen: $_group');
      return false;
    }
    int count = await _table.updateMembers(newMembers, oldMembers, _group);
    return count > 0;
  }

}

class MemberCache extends DataCache<ID, List<ID>> {
  MemberCache() : super('group_members');

  final _MemberTable _table = _MemberTable();

  _MemTask _newTask(ID group, {List<ID>? oldMembers}) =>
      _MemTask(mutexLock, cachePool, _table, group, oldMembers: oldMembers);

  Future<List<ID>> getMembers(ID group) async {
    var task = _newTask(group);
    var contacts = await task.load();
    return contacts ?? [];
  }

  Future<bool> _updateMembers(List<ID> newMembers, List<ID> oldMembers, {required ID group}) async {
    var task = _newTask(group, oldMembers: oldMembers);
    return await task.save(newMembers);
  }

  Future<bool> saveMembers(List<ID> newMembers, ID group) async {
    // save new members
    var oldMembers = await getMembers(group);
    var ok = await _updateMembers(newMembers, oldMembers, group: group);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMembersUpdated, this, {
        'action': 'update',
        'ID': group,
        'group': group,
        'members': newMembers,
      });
    }
    return ok;
  }

  Future<bool> addMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    if (oldMembers.contains(member)) {
      logWarning('member exists: $member, group: $group');
      return true;
    }
    List<ID> newMembers = [...oldMembers, member];
    var ok = await _updateMembers(newMembers, oldMembers, group: group);
    if (ok) {
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
    return ok;
  }

  Future<bool> removeMember(ID member, {required ID group}) async {
    List<ID> oldMembers = await getMembers(group);
    if (!oldMembers.contains(member)) {
      logWarning('member not exists: $member, group: $group');
      return true;
    }
    List<ID> newMembers = [...oldMembers];
    newMembers.removeWhere((element) => element == member);
    var ok = await _updateMembers(newMembers, oldMembers, group: group);
    if (ok) {
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
    return ok;
  }

}
