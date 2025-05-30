
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
  Future<bool> removeMember(ID member, {required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'member', comparison: '=', right: member.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove member: $member, group: $group');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addMember(ID member, {required ID group}) async {
    // add new record
    List values = [
      group.toString(),
      member.toString(),
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add member: $member, group: $group');
      return false;
    }
    return true;
  }

  // protected
  Future<List<ID>> loadMembers(ID group) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

}

class _MemTask extends DbTask<ID, List<ID>> {
  _MemTask(super.mutexLock, super.cachePool, this._table, this._group, {
    required ID? append,
    required ID? remove,
  }) : _append = append, _remove = remove;

  final ID _group;

  final ID? _append;
  final ID? _remove;

  final _MemberTable _table;

  @override
  ID get cacheKey => _group;

  @override
  Future<List<ID>?> readData() async {
    return await _table.loadMembers(_group);
  }

  @override
  Future<bool> writeData(List<ID> members) async {
    // 1. add
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addMember(append, group: _group);
      if (ok1) {
        members.add(append);
      }
    }
    // 2. remove
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok2 = await _table.removeMember(remove, group: _group);
      if (ok2) {
        members.remove(remove);
      }
    }
    return ok1 || ok2;
  }

}

class MemberCache extends DataCache<ID, List<ID>> {
  MemberCache() : super('group_members');

  final _MemberTable _table = _MemberTable();

  _MemTask _newTask(ID group, {ID? append, ID? remove}) =>
      _MemTask(mutexLock, cachePool, _table, group, append: append, remove: remove);

  Future<List<ID>> getMembers(ID group) async {
    var task = _newTask(group);
    var contacts = await task.load();
    return contacts ?? [];
  }

  Future<bool> saveMembers(List<ID> newMembers, ID group) async {
    var task = _newTask(group);
    var allMembers = await task.load();
    allMembers ??= [];

    var oldMembers = [...allMembers];
    int count = 0;
    // 1. remove
    for (ID item in oldMembers) {
      if (newMembers.contains(item)) {
        continue;
      }
      task = _newTask(group, remove: item);
      if (await task.save(allMembers)) {
        ++count;
      } else {
        logError('failed to remove member: $item, group: $group');
        return false;
      }
    }
    // 2. add
    for (ID item in newMembers) {
      if (oldMembers.contains(item)) {
        continue;
      }
      task = _newTask(group, append: item);
      if (await task.save(allMembers)) {
        ++count;
      } else {
        logError('failed to add member: $item, group: $group');
        return false;
      }
    }

    if (count == 0) {
      logWarning('members not changed: $group');
    } else {
      logInfo('updated $count member(s) for group: $group');
    }

    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMembersUpdated, this, {
      'action': 'update',
      'ID': group,
      'group': group,
      'members': newMembers,
    });
    return true;
  }

  Future<bool> addMember(ID member, {required ID group}) async {
    var task = _newTask(group);
    var allMembers = await task.load();
    if (allMembers == null) {
      allMembers = [];
    } else if (allMembers.contains(member)) {
      logWarning('member exists: $member, group: $group');
      return true;
    }
    task = _newTask(group, append: member);
    var ok = await task.save(allMembers);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
        'ID': group,
        'group': group,
        'member': member,
        'members': allMembers,
      });
    }
    return ok;
  }

  Future<bool> removeMember(ID member, {required ID group}) async {
    var task = _newTask(group);
    var allMembers = await task.load();
    if (allMembers == null) {
      logError('failed to get members');
      return false;
    } else if (allMembers.contains(member)) {
      // found
    } else {
      logWarning('member not exists: $member, group: $group');
      return true;
    }
    task = _newTask(group, remove: member);
    var ok = await task.save(allMembers);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'ID': group,
        'group': group,
        'member': member,
        'members': allMembers,
      });
    }
    return ok;
  }

}
