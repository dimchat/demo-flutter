
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/dbi/contact.dart';
import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


ID _extractBlocked(ResultSet resultSet, int index) {
  String? user = resultSet.getString('blocked');
  return ID.parse(user)!;
}

class _BlockedTable extends DataTableHandler<ID> {
  _BlockedTable() : super(EntityDatabase(), _extractBlocked);

  static const String _table = EntityDatabase.tBlocked;
  static const List<String> _selectColumns = ["blocked"];
  static const List<String> _insertColumns = ["uid", "blocked"];

  // protected
  Future<int> updateBlockList(List<ID> newContacts, List<ID> oldContacts, ID user) async {
    assert(!identical(newContacts, oldContacts), 'should not be the same object');
    SQLConditions cond;

    // 0. check new block-list
    if (newContacts.isEmpty) {
      assert(oldContacts.isNotEmpty, 'new block-list empty??');
      cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to clear block-list for user: $user');
        return -1;
      }
      logWarning('block-list cleared for user: $user');
      return oldContacts.length;
    }
    int count = 0;

    // 1. remove
    for (ID item in oldContacts) {
      if (newContacts.contains(item)) {
        continue;
      }
      cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
      cond.addCondition(SQLConditions.kAnd,
          left: 'blocked', comparison: '=', right: item.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to remove blocked: $item, user: $user');
        return -1;
      }
      ++count;
    }

    // 2. add
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue;
      }
      List values = [user.toString(), item.toString()];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        logError('failed to add blocked: $item, user: $user');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      logWarning('block-list not changed: $user');
      return 0;
    }
    logInfo('updated $count blocked contact(s) for user: $user');
    return count;
  }

  // protected
  Future<List<ID>> getBlockList(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

}

class _BlockedTask extends DbTask<ID, List<ID>> {
  _BlockedTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required List<ID>? oldContacts,
  }) : _oldContacts = oldContacts;

  final ID _user;

  final List<ID>? _oldContacts;

  final _BlockedTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ID>?> readData() async {
    return await _table.getBlockList(_user);
  }

  @override
  Future<bool> writeData(List<ID> newContacts) async {
    List<ID>? oldContacts = _oldContacts;
    if (oldContacts == null) {
      assert(false, 'should not happen: $_user');
      return false;
    }
    int count = await _table.updateBlockList(newContacts, oldContacts, _user);
    return count > 0;
  }

}

class BlockedCache extends DataCache<ID, List<ID>> implements BlockedDBI {
  BlockedCache() : super('blocked_list');

  final _BlockedTable _table = _BlockedTable();

  _BlockedTask _newTask(ID user, {List<ID>? oldContacts}) =>
      _BlockedTask(mutexLock, cachePool, _table, user, oldContacts: oldContacts);

  @override
  Future<List<ID>> getBlockList({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  Future<bool> _updateBlockedList(List<ID> newContacts, List<ID> oldContacts, {required ID user}) async {
    var task = _newTask(user, oldContacts: oldContacts);
    return await task.save(newContacts);
  }

  @override
  Future<bool> saveBlockList(List<ID> newContacts, {required ID user}) async {
    // save new contacts
    var oldContacts = await getBlockList(user: user);
    var ok = await _updateBlockedList(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'update',
        'user': user,
        'block_list': newContacts,
      });
    }
    return ok;
  }

  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    if (oldContacts.contains(contact)) {
      logWarning('blocked exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    var ok = await _updateBlockedList(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'add',
        'user': user,
        'blocked': contact,
        'block_list': newContacts,
      });
    }
    return ok;
  }

  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    if (!oldContacts.contains(contact)) {
      logWarning('blocked not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    var ok = await _updateBlockedList(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unblocked': contact,
        'block_list': newContacts,
      });
    }
    return ok;
  }

}
