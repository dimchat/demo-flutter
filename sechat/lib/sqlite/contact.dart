import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'entity.dart';


ID _extractContact(ResultSet resultSet, int index) {
  String? user = resultSet.getString('contact');
  return ID.parse(user)!;
}

class _ContactTable extends DataTableHandler<ID> implements ContactDBI {
  _ContactTable() : super(EntityDatabase(), _extractContact);

  static const String _table = EntityDatabase.tContact;
  static const List<String> _selectColumns = ["contact", "alias"];
  static const List<String> _insertColumns = ["uid", "contact", "alias"];

  // protected
  Future<int> updateContacts(List<ID> newContacts, List<ID> oldContacts, ID user) async {
    assert(!identical(newContacts, oldContacts), 'should not be the same object');
    SQLConditions cond;

    // 0. check new contacts
    if (newContacts.isEmpty) {
      assert(oldContacts.isNotEmpty, 'new contacts empty??');
      cond = SQLConditions(left: 'uid', comparison: '=', right: user.string);
      if (await delete(_table, conditions: cond) < 0) {
        Log.error('failed to clear contacts for user: $user');
        return -1;
      }
      Log.warning('contacts cleared for user: $user');
      return oldContacts.length;
    }
    int count = 0;

    // 1. remove
    for (ID item in oldContacts) {
      if (newContacts.contains(item)) {
        continue;
      }
      cond = SQLConditions(left: 'uid', comparison: '=', right: user.string);
      cond.addCondition(SQLConditions.kAnd,
          left: 'contact', comparison: '=', right: item.string);
      if (await delete(_table, conditions: cond) < 0) {
        Log.error('failed to remove contact: $item, user: $user');
        return -1;
      }
      ++count;
    }

    // 2. add
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue;
      }
      List values = [user.string, item.string, ''];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        Log.error('failed to add contact: $item, user: $user');
        return -1;
      }
      ++count;
    }

    if (count == 0) {
      Log.warning('contacts not changed: $user');
      return 0;
    }
    Log.info('updated $count contact(s) for user: $user');
    return count;
  }

  @override
  Future<List<ID>> getContacts({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.string);
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<bool> saveContacts(List<ID> contacts, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    return await updateContacts(contacts, oldContacts, user) >= 0;
  }

  @override
  Future<bool> addContact(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    if (oldContacts.contains(contact)) {
      Log.warning('contact exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    return await updateContacts(newContacts, oldContacts, user) >= 0;
  }

  @override
  Future<bool> removeContact(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    if (!oldContacts.contains(contact)) {
      Log.warning('contact not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    return await updateContacts(newContacts, oldContacts, user) >= 0;
  }

}

class ContactCache extends _ContactTable {

  final Map<ID, List<ID>> _caches = {};

  @override
  Future<List<ID>> getContacts({required ID user}) async {
    List<ID>? array = _caches[user];
    if (array == null) {
      // cache not found, try to load from database
      array = await super.getContacts(user: user);
      // add to cache
      _caches[user] = array;
    }
    return array;
  }

  @override
  Future<bool> saveContacts(List<ID> contacts, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    int cnt = await updateContacts(contacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'update',
        'user': user,
        'contacts': contacts,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> addContact(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    if (oldContacts.contains(contact)) {
      Log.warning('contact exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts, contact];
    int cnt = await updateContacts(newContacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
        'user': user,
        'contact': contact,
        'contacts': newContacts,
      });
    }
    return cnt >= 0;
  }

  @override
  Future<bool> removeContact(ID contact, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    if (!oldContacts.contains(contact)) {
      Log.warning('contact not exists: $contact, user: $user');
      return true;
    }
    List<ID> newContacts = [...oldContacts];
    newContacts.removeWhere((element) => element == contact);
    int cnt = await updateContacts(newContacts, oldContacts, user);
    if (cnt > 0) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'user': user,
        'contact': contact,
        'contacts': newContacts,
      });
    }
    return cnt >= 0;
  }

}
