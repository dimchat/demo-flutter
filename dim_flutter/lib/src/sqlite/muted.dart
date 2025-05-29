
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/dbi/contact.dart';
import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


ID _extractMuted(ResultSet resultSet, int index) {
  String? user = resultSet.getString('muted');
  return ID.parse(user)!;
}

class _MutedTable extends DataTableHandler<ID> {
  _MutedTable() : super(EntityDatabase(), _extractMuted);

  static const String _table = EntityDatabase.tMuted;
  static const List<String> _selectColumns = ["muted"];
  static const List<String> _insertColumns = ["uid", "muted"];

  // protected
  Future<int> updateMuteList(List<ID> newContacts, List<ID> oldContacts, ID user) async {
    assert(!identical(newContacts, oldContacts), 'should not be the same object');
    SQLConditions cond;

    // 0. check new mute-list
    if (newContacts.isEmpty) {
      assert(oldContacts.isNotEmpty, 'new mute-list empty??');
      cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to clear mute-list for user: $user');
        return -1;
      }
      logWarning('mute-list cleared for user: $user');
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
          left: 'muted', comparison: '=', right: item.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to remove muted: $item, user: $user');
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
        logError('failed to add muted: $item, user: $user');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      logWarning('mute-list not changed: $user');
      return 0;
    }
    logInfo('updated $count muted contact(s) for user: $user');
    return count;
  }

  // protected
  Future<List<ID>> getMuteList(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

}

class _MutedTask extends DbTask<ID, List<ID>> {
  _MutedTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required List<ID>? oldContacts,
  }) : _oldContacts = oldContacts;

  final ID _user;

  final List<ID>? _oldContacts;

  final _MutedTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ID>?> readData() async {
    return await _table.getMuteList(_user);
  }

  @override
  Future<bool> writeData(List<ID> newContacts) async {
    List<ID>? oldContacts = _oldContacts;
    if (oldContacts == null) {
      assert(false, 'should not happen: $_user');
      return false;
    }
    int count = await _table.updateMuteList(newContacts, oldContacts, _user);
    return count > 0;
  }

}

class MutedCache extends DataCache<ID, List<ID>> implements MutedDBI {
  MutedCache() : super('muted_list');

  final _MutedTable _table = _MutedTable();

  _MutedTask _newTask(ID user, {List<ID>? oldContacts}) =>
      _MutedTask(mutexLock, cachePool, _table, user, oldContacts: oldContacts);

  @override
  Future<List<ID>> getMuteList({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  Future<bool> _updateMutedList(List<ID> newContacts, List<ID> oldContacts, {required ID user}) async {
    var task = _newTask(user, oldContacts: oldContacts);
    return await task.save(newContacts);
  }

  @override
  Future<bool> saveMuteList(List<ID> newContacts, {required ID user}) async {
    // save new contacts
    var oldContacts = await getMuteList(user: user);
    var ok = await _updateMutedList(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'update',
        'user': user,
        'mute_list': newContacts,
      });
    }
    return ok;
  }

  @override
  Future<bool> addMuted(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    if (oldContacts.contains(contact)) {
      logWarning('muted exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    var ok = await _updateMutedList(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'add',
        'user': user,
        'muted': contact,
        'mute_list': newContacts,
      });
    }
    return ok;
  }

  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    if (!oldContacts.contains(contact)) {
      logWarning('muted not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    var ok = await _updateMutedList(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unmuted': contact,
        'mute_list': newContacts,
      });
    }
    return ok;
  }

}
