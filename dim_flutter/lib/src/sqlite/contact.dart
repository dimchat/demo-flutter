
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
  Future<bool> removeContact(ID contact, {required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'contact', comparison: '=', right: contact.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove contact: $contact, user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addContact(ID contact, {required ID user}) async {
    // add new record
    List values = [
      user.toString(),
      contact.toString(),
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add contact: $contact, user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<List<ID>> loadContacts({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

}

class _ContactTask extends DbTask<ID, List<ID>> {
  _ContactTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required ID? append,
    required ID? remove,
  }) : _append = append, _remove = remove;

  final ID _user;

  final ID? _append;
  final ID? _remove;

  final _ContactTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ID>?> readData() async {
    return await _table.loadContacts(user: _user);
  }

  @override
  Future<bool> writeData(List<ID> contacts) async {
    // 1. add
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addContact(append, user: _user);
      if (ok1) {
        contacts.add(append);
      }
    }
    // 2. remove
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok2 = await _table.removeContact(remove, user: _user);
      if (ok2) {
        contacts.remove(remove);
      }
    }
    return ok1 || ok2;
  }

}

class ContactCache extends DataCache<ID, List<ID>> implements ContactDBI  {
  ContactCache() : super('user_contacts');

  final _ContactTable _table = _ContactTable();

  _ContactTask _newTask(ID user, {ID? append, ID? remove}) =>
      _ContactTask(mutexLock, cachePool, _table, user, append: append, remove: remove);

  @override
  Future<List<ID>> getContacts({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  @override
  Future<bool> saveContacts(List<ID> newContacts, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    allContacts ??= [];

    var oldContacts = [...allContacts];
    int count = 0;
    // 1. remove
    for (ID item in oldContacts) {
      if (newContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, remove: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to remove contact: $item, user: $user');
        return false;
      }
    }
    // 2. add
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, append: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to add contact: $item, user: $user');
        return false;
      }
    }

    if (count == 0) {
      logWarning('contacts not changed: $user');
    } else {
      logInfo('updated $count contact(s) for user: $user');
    }

    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kContactsUpdated, this, {
      'action': 'update',
      'user': user,
      'contacts': newContacts,
    });
    return true;
  }

  Future<bool> addContact(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      allContacts = [];
    } else if (allContacts.contains(contact)) {
      logWarning('contact exists: $contact');
      return true;
    }
    task = _newTask(user, append: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
        'user': user,
        'contact': contact,
        'contacts': allContacts,
      });
    }
    return ok;
  }

  Future<bool> removeContact(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      logError('failed to get contacts');
      return false;
    } else if (allContacts.contains(contact)) {
      // found
    } else {
      logWarning('contact not exists: $user');
      return true;
    }
    task = _newTask(user, remove: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'user': user,
        'contact': contact,
        'contacts': allContacts,
      });
    }
    return ok;
  }

}
