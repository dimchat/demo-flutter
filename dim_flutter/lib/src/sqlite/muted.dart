import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';

import '../common/dbi/contact.dart';
import '../common/constants.dart';
import 'helper/sqlite.dart';

import 'entity.dart';


ID _extractMuted(ResultSet resultSet, int index) {
  String? user = resultSet.getString('muted');
  return ID.parse(user)!;
}

class _MutedTable extends DataTableHandler<ID> implements MutedDBI {
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
        Log.error('failed to clear mute-list for user: $user');
        return -1;
      }
      Log.warning('mute-list cleared for user: $user');
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
        Log.error('failed to remove muted: $item, user: $user');
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
        Log.error('failed to add muted: $item, user: $user');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      Log.warning('mute-list not changed: $user');
      return 0;
    }
    Log.info('updated $count muted contact(s) for user: $user');
    return count;
  }

  @override
  Future<List<ID>> getMuteList({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<bool> saveMuteList(List<ID> contacts, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    return await updateMuteList(contacts, oldContacts, user) >= 0;
  }

  @override
  Future<bool> addMuted(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    if (oldContacts.contains(contact)) {
      Log.warning('muted exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    return await updateMuteList(newContacts, oldContacts, user) >= 0;
  }

  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    if (!oldContacts.contains(contact)) {
      Log.warning('muted not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    return await updateMuteList(newContacts, oldContacts, user) >= 0;
  }

}

class MutedCache extends _MutedTable {

  final Map<ID, List<ID>> _caches = {};

  @override
  Future<List<ID>> getMuteList({required ID user}) async {
    List<ID>? array;
    await lock();
    try {
      array = _caches[user];
      if (array == null) {
        // cache not found, try to load from database
        array = await super.getMuteList(user: user);
        // add to cache
        _caches[user] = array;
      }
    } finally {
      unlock();
    }
    return array;
  }

  @override
  Future<bool> saveMuteList(List<ID> contacts, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    int cnt = await updateMuteList(contacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'update',
        'user': user,
        'mute_list': contacts,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> addMuted(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    if (oldContacts.contains(contact)) {
      Log.warning('muted exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    int cnt = await updateMuteList(newContacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'add',
        'user': user,
        'muted': contact,
        'mute_list': newContacts,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getMuteList(user: user);
    if (!oldContacts.contains(contact)) {
      Log.warning('muted not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    int cnt = await updateMuteList(newContacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unmuted': contact,
        'mute_list': newContacts,
      });
    }
    return cnt >= 0;
  }

}
