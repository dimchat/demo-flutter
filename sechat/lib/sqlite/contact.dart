import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'entity.dart';


ID _extractContact(ResultSet resultSet, int index) {
  String? user = resultSet.getString('contact');
  return ID.parse(user)!;
}

class ContactTable extends DataTableHandler<ID> implements ContactDBI {
  ContactTable() : super(EntityDatabase(), _extractContact);

  static const String _table = EntityDatabase.tContact;
  static const List<String> _selectColumns = ["contact", "alias"];
  static const List<String> _insertColumns = ["uid", "contact", "alias"];

  final Map<ID, List<ID>> _caches = {};

  Future<int> _updateContacts(List<ID> newContacts, List<ID> oldContacts, ID user) async {
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
      _caches.remove(user);
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
    _caches[user] = newContacts;
    return count;
  }

  @override
  Future<List<ID>> getContacts({required ID user}) async {
    List<ID>? array = _caches[user];
    if (array == null) {
      // cache not found, try to load from database
      SQLConditions cond;
      cond = SQLConditions(left: 'uid', comparison: '=', right: user.string);
      array = await select(_table, columns: _selectColumns, conditions: cond);
      // add to cache
      _caches[user] = array;
    }
    return array;
  }

  @override
  Future<bool> saveContacts(List<ID> contacts, {required ID user}) async {
    List<ID> oldContacts = await getContacts(user: user);
    int cnt = await _updateContacts(contacts, oldContacts, user);
    if (cnt > 0) {
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
    List<ID> newContacts = [...oldContacts, contact];
    int cnt = await _updateContacts(newContacts, oldContacts, user);
    if (cnt > 0) {
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
    List<ID> newContacts = [...oldContacts];
    newContacts.remove(contact);
    int cnt = await _updateContacts(newContacts, oldContacts, user);
    if (cnt > 0) {
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
