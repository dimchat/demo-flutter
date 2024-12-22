
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/dbi/contact.dart';
import '../common/constants.dart';
import 'helper/sqlite.dart';

import 'entity.dart';


ID _extractBlocked(ResultSet resultSet, int index) {
  String? user = resultSet.getString('blocked');
  return ID.parse(user)!;
}

class _BlockedTable extends DataTableHandler<ID> implements BlockedDBI {
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
        Log.error('failed to clear block-list for user: $user');
        return -1;
      }
      Log.warning('block-list cleared for user: $user');
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
        Log.error('failed to remove blocked: $item, user: $user');
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
        Log.error('failed to add blocked: $item, user: $user');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      Log.warning('block-list not changed: $user');
      return 0;
    }
    Log.info('updated $count blocked contact(s) for user: $user');
    return count;
  }

  @override
  Future<List<ID>> getBlockList({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<bool> saveBlockList(List<ID> contacts, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    return await updateBlockList(contacts, oldContacts, user) >= 0;
  }

  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    if (oldContacts.contains(contact)) {
      Log.warning('blocked exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    return await updateBlockList(newContacts, oldContacts, user) >= 0;
  }

  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    if (!oldContacts.contains(contact)) {
      Log.warning('blocked not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    return await updateBlockList(newContacts, oldContacts, user) >= 0;
  }

}

class BlockedCache extends _BlockedTable {

  final Map<ID, List<ID>> _caches = {};

  @override
  Future<List<ID>> getBlockList({required ID user}) async {
    List<ID>? array;
    await lock();
    try {
      array = _caches[user];
      if (array == null) {
        // cache not found, try to load from database
        array = await super.getBlockList(user: user);
        // add to cache
        _caches[user] = array;
      }
    } finally {
      unlock();
    }
    return array;
  }

  @override
  Future<bool> saveBlockList(List<ID> contacts, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    int cnt = await updateBlockList(contacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'update',
        'user': user,
        'block_list': contacts,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    if (oldContacts.contains(contact)) {
      Log.warning('blocked exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    int cnt = await updateBlockList(newContacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'add',
        'user': user,
        'blocked': contact,
        'block_list': newContacts,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getBlockList(user: user);
    if (!oldContacts.contains(contact)) {
      Log.warning('blocked not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    int cnt = await updateBlockList(newContacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unblocked': contact,
        'block_list': newContacts,
      });
    }
    return cnt >= 0;
  }

}
