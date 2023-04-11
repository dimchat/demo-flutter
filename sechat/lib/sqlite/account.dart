import 'package:dim_client/dim_client.dart';
import 'package:sqflite/sqflite.dart';

import '../client/dbi/account.dart';
import 'helper/connector.dart';
import 'helper/handler.dart';

class _UserExtractor implements DataRowExtractor<ID> {

  @override
  ID extractRow(ResultSet resultSet, int index) {
    String user = resultSet.getString('user');
    return ID.parse(user)!;
  }

}

class UserDB extends DataTableHandler<ID> implements UserTable {
  UserDB()
      : super(DatabaseConnector(name: name, version: version, onCreate: onCreate));

  static const String name = 'user.db';
  static const int version = 1;

  static const String _table = 't_local_user';
  static const List<String> _selectColumns = ['user'];
  static const List<String> _insertColumns = ['user', 'chosen'];

  static Future<void> onCreate(Database db, int version) => db.execute(
      SQLBuilder.buildCreateTable(name, fields: [
        'id INTEGER PRIMARY KEY AUTOINCREMENT',
        'user VARCHAR(64)',
        'chosen BIT',
      ])
  );

  @override
  DataRowExtractor<ID> get extractor => _UserExtractor();

  Future<bool> _updateUsers(List<ID> newUsers, List<ID> oldUsers) async {
    assert(!identical(newUsers, oldUsers), 'should not be the same object');
    SQLConditions cond;
    // 0. check new users
    if (newUsers.isEmpty) {
      assert(false, 'new users empty??');
      return await delete(_table, conditions: SQLConditions.any) > 0;
    }
    ID current = newUsers[0];
    bool resign = true;
    // 1. check old users
    if (oldUsers.isNotEmpty) {
      resign = !oldUsers.contains(current);
      int count = 0;
      for (ID item in oldUsers) {
        if (newUsers.contains(item)) {
          continue;
        }
        // delete records not contain in new users
        cond = SQLConditions(left: 'user', comparison: '=', right: item.string);
        if (await delete(_table, conditions: cond) < 0) {
          // db error
          return false;
        }
        ++count;
      }
      if (resign && count < oldUsers.length) {
        // current user changed, and not all old users removed,
        // erase chosen flags for them
        Map<String, dynamic> values = {'chosen': 0};
        if (await update(_table, values: values, conditions: SQLConditions.any) < 0) {
          // db error
          return false;
        }
      }
    }
    // 2. check current user
    if (resign) {
      // add current user with chosen flag = 1
      List values = [current.string, 1];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        // db error
        return false;
      }
    }
    // 3. check other new users
    for (int index = 1; index < newUsers.length; ++index) {
      ID item = newUsers[index];
      if (oldUsers.contains(item)) {
        continue;
      }
      // add other user with chosen flag = 0
      List values = [item.string, 0];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        // db error
        return false;
      }
    }
    return true;
  }

  @override
  Future<List<ID>> getLocalUsers() async =>
      await select(_table, columns: _selectColumns, conditions: SQLConditions.any);

  @override
  Future<bool> saveLocalUsers(List<ID> users) async {
    List<ID> localUsers = await getLocalUsers();
    return await _updateUsers(users, localUsers);
  }

  @override
  Future<bool> addUser(ID user) async {
    List<ID> localUsers = await getLocalUsers();
    if (localUsers.contains(user)) {
      return false;
    }
    List<ID> newUsers = [...localUsers, user];
    return await _updateUsers(newUsers, localUsers);
  }

  @override
  Future<bool> removeUser(ID user) async {
    List<ID> localUsers = await getLocalUsers();
    if (!localUsers.contains(user)) {
      return false;
    }
    List<ID> newUsers = [...localUsers];
    newUsers.remove(user);
    return await _updateUsers(newUsers, localUsers);
  }

  @override
  Future<bool> setCurrentUser(ID user) async {
    List<ID> localUsers = await getLocalUsers();
    if (localUsers.isEmpty) {
      // first user
      return await _updateUsers([user], localUsers);
    } else if (localUsers[0] == user) {
      // not change
      return false;
    }
    List<ID> newUsers = [...localUsers];
    if (newUsers.contains(user)) {
      // move to front
      newUsers.remove(user);
    }
    newUsers.insert(0, user);
    return await _updateUsers(newUsers, localUsers);
  }

  @override
  Future<ID?> getCurrentUser() async {
    List<ID> localUsers = await getLocalUsers();
    return localUsers.isEmpty ? null : localUsers[0];
  }

  @override
  Future<List<ID>> getContacts(ID user) =>
      throw UnimplementedError('call ContactTable');

  @override
  Future<bool> saveContacts(List<ID> contacts, ID user) =>
      throw UnimplementedError('call ContactTable');

}

class _ContactExtractor implements DataRowExtractor<ID> {

  @override
  ID extractRow(ResultSet resultSet, int index) {
    String user = resultSet.getString('contact');
    return ID.parse(user)!;
  }

}

class ContactDB extends DataTableHandler<ID> implements ContactTable {
  ContactDB()
      : super(DatabaseConnector(name: name, version: version, onCreate: onCreate));

  static const String name = 'user.db';
  static const int version = 1;

  static const String _table = 't_contact';
  static const List<String> _selectColumns = ['contact', 'alias'];
  static const List<String> _insertColumns = ['user', 'contact', 'alias'];

  static Future<void> onCreate(Database db, int version) => db.execute(
      SQLBuilder.buildCreateTable(name, fields: [
        'id INTEGER PRIMARY KEY AUTOINCREMENT',
        'user VARCHAR(64)',
        'contact VARCHAR(64)',
        'alias VARCHAR(32))',
      ])
  );

  @override
  DataRowExtractor<ID> get extractor => _ContactExtractor();

  Future<bool> _updateContacts(List<ID> contacts, ID user) async {
    SQLConditions cond;
    // 0. remove old records
    cond = SQLConditions(left: 'user', comparison: '=', right: user.string);
    if (await delete(_table, conditions: cond) < 0) {
      // db error
      return false;
    }
    // 1. add new records
    for (ID item in contacts) {
      List values = [user.string, item.string, ''];
      if (await insert(_table, columns: _insertColumns, values: values) < 0) {
        // db error
        return false;
      }
    }
    return true;
  }

  @override
  Future<List<ID>> getLocalUsers() =>
      throw UnimplementedError('call UserTable');

  @override
  Future<bool> saveLocalUsers(List<ID> users) =>
      throw UnimplementedError('call UserTable');

  @override
  Future<List<ID>> getContacts(ID user) async =>
      await select(_table, columns: _selectColumns, conditions: SQLConditions.any);

  @override
  Future<bool> saveContacts(List<ID> contacts, ID user) async {
    return await _updateContacts(contacts, user);
  }

  @override
  Future<bool> addContact(ID contact, {required ID user}) async {
    List values = [user.string, contact.string, ''];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> removeContact(ID contact, {required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'user', comparison: '=', right: user.string);
    cond.addCondition(SQLConditions.and,
        left: 'contact', comparison: '=', right: contact.string);
    return await delete(_table, conditions: cond) > 0;
  }

}
