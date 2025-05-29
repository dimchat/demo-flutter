
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


ID _extractContact(ResultSet resultSet, int index) {
  String? user = resultSet.getString('contact');
  return ID.parse(user)!;
}

class _ContactTable extends DataTableHandler<ID> {
  _ContactTable() : super(EntityDatabase(), _extractContact);

  static const String _table = EntityDatabase.tContact;
  static const List<String> _selectColumns = ["contact"];
  static const List<String> _insertColumns = ["uid", "contact"];

  // protected
  Future<int> updateContacts(List<ID> newContacts, List<ID> oldContacts, ID user) async {
    assert(!identical(newContacts, oldContacts), 'should not be the same object');
    SQLConditions cond;

    // 0. check new contacts
    if (newContacts.isEmpty) {
      assert(oldContacts.isNotEmpty, 'new contacts empty??');
      cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to clear contacts for user: $user');
        return -1;
      }
      logWarning('contacts cleared for user: $user');
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
          left: 'contact', comparison: '=', right: item.toString());
      if (await delete(_table, conditions: cond) < 0) {
        logError('failed to remove contact: $item, user: $user');
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
        logError('failed to add contact: $item, user: $user');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      logWarning('contacts not changed: $user');
      return 0;
    }
    logInfo('updated $count contact(s) for user: $user');
    return count;
  }

  // protected
  Future<List<ID>> getContacts({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

}

class _ContactTask extends DbTask<ID, List<ID>> {
  _ContactTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required List<ID>? oldContacts,
  }) : _oldContacts = oldContacts;

  final ID _user;

  final List<ID>? _oldContacts;

  final _ContactTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ID>?> readData() async {
    return await _table.getContacts(user: _user);
  }

  @override
  Future<bool> writeData(List<ID> newContacts) async {
    List<ID>? oldContacts = _oldContacts;
    if (oldContacts == null) {
      assert(false, 'should not happen: $_user');
      return false;
    }
    int count = await _table.updateContacts(newContacts, oldContacts, _user);
    return count > 0;
  }

}

class ContactCache extends DataCache<ID, List<ID>> implements ContactDBI  {
  ContactCache() : super('user_contacts');

  final _ContactTable _table = _ContactTable();

  _ContactTask _newTask(ID user, {List<ID>? oldContacts}) =>
      _ContactTask(mutexLock, cachePool, _table, user, oldContacts: oldContacts);

  @override
  Future<List<ID>> getContacts({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  Future<bool> _updateContacts(List<ID> newContacts, List<ID> oldContacts, {required ID user}) async {
    var task = _newTask(user, oldContacts: oldContacts);
    return await task.save(newContacts);
  }

  @override
  Future<bool> saveContacts(List<ID> newContacts, {required ID user}) async {
    // save new contacts
    var oldContacts = await getContacts(user: user);
    var ok = await _updateContacts(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'update',
        'user': user,
        'contacts': newContacts,
      });
    }
    return ok;
  }

  Future<bool> addContact(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    if (oldContacts.contains(contact)) {
      logWarning('contact exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    bool ok = await _updateContacts(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
        'user': user,
        'contact': contact,
        'contacts': newContacts,
      });
    }
    return ok;
  }

  Future<bool> removeContact(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    if (!oldContacts.contains(contact)) {
      logWarning('contact not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    bool ok = await _updateContacts(newContacts, oldContacts, user: user);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'user': user,
        'contact': contact,
        'contacts': newContacts,
      });
    }
    return ok;
  }

}
