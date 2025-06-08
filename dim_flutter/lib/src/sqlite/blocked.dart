
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
  Future<bool> removeBlocked(ID contact, {required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'blocked', comparison: '=', right: contact.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove blocked: $contact, user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    // add new record
    List values = [
      user.toString(),
      contact.toString(),
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add blocked: $contact, user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<List<ID>> loadBlockedList(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

}

class _BlockedTask extends DbTask<ID, List<ID>> {
  _BlockedTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required ID? blocked,
    required ID? allowed,
  }) : _blocked = blocked, _allowed = allowed;

  final ID _user;

  final ID? _blocked;
  final ID? _allowed;

  final _BlockedTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ID>?> readData() async {
    return await _table.loadBlockedList(_user);
  }

  @override
  Future<bool> writeData(List<ID> contacts) async {
    // 1. add to block
    bool ok1 = false;
    ID? blocked = _blocked;
    if (blocked != null) {
      ok1 = await _table.addBlocked(blocked, user: _user);
      if (ok1) {
        contacts.add(blocked);
      }
    }
    // 2. remove to allow
    bool ok2 = false;
    ID? allowed = _allowed;
    if (allowed != null) {
      ok2 = await _table.removeBlocked(allowed, user: _user);
      if (ok2) {
        contacts.remove(allowed);
      }
    }
    return ok1 || ok2;
  }

}

class BlockedCache extends DataCache<ID, List<ID>> implements BlockedDBI {
  BlockedCache() : super('blocked_list');

  final _BlockedTable _table = _BlockedTable();

  _BlockedTask _newTask(ID user, {ID? blocked, ID? allowed}) =>
      _BlockedTask(mutexLock, cachePool, _table, user, blocked: blocked, allowed: allowed);

  @override
  Future<List<ID>> getBlockList({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  @override
  Future<bool> saveBlockList(List<ID> newContacts, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    allContacts ??= [];

    var oldContacts = [...allContacts];
    int count = 0;
    // 1. remove to allow
    for (ID item in oldContacts) {
      if (newContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, allowed: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to remove blocked: $item, user: $user');
        return false;
      }
    }
    // 2. add to block
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, blocked: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to add blocked: $item, user: $user');
        return false;
      }
    }

    if (count == 0) {
      logWarning('blocked-list not changed: $user');
    } else {
      logInfo('updated $count blocked contact(s) for user: $user');
    }

    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kBlockListUpdated, this, {
      'action': 'update',
      'user': user,
      'blocked_list': newContacts,
    });
    return true;
  }

  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      allContacts = [];
    } else if (allContacts.contains(contact)) {
      logWarning('blocked contact exists: $contact');
      return true;
    }
    task = _newTask(user, blocked: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'add',
        'user': user,
        'blocked': contact,
        'blocked_list': allContacts,
      });
    }
    return ok;
  }

  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      logError('failed to get blocked-list');
      return false;
    } else if (allContacts.contains(contact)) {
      // found
    } else {
      logWarning('blocked contact not exists: $user');
      return true;
    }
    task = _newTask(user, allowed: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unblocked': contact,
        'blocked_list': allContacts,
      });
    }
    return ok;
  }

}
