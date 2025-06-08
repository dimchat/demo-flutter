
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
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'muted', comparison: '=', right: contact.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove muted: $contact, user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addMuted(ID contact, {required ID user}) async {
    // add new record
    List values = [
      user.toString(),
      contact.toString(),
    ];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add muted: $contact, user: $user');
      return false;
    }
    return true;
  }

  // protected
  Future<List<ID>> loadMutedList(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

}

class _MutedTask extends DbTask<ID, List<ID>> {
  _MutedTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required ID? muted,
    required ID? allowed,
  }) : _muted = muted, _allowed = allowed;

  final ID _user;

  final ID? _muted;
  final ID? _allowed;

  final _MutedTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ID>?> readData() async {
    return await _table.loadMutedList(_user);
  }

  @override
  Future<bool> writeData(List<ID> contacts) async {
    // 1. add to muted
    bool ok1 = false;
    ID? muted = _muted;
    if (muted != null) {
      ok1 = await _table.addMuted(muted, user: _user);
      if (ok1) {
        contacts.add(muted);
      }
    }
    // 2. remove to allow
    bool ok2 = false;
    ID? allowed = _allowed;
    if (allowed != null) {
      ok2 = await _table.removeMuted(allowed, user: _user);
      if (ok2) {
        contacts.remove(allowed);
      }
    }
    return ok1 || ok2;
  }

}

class MutedCache extends DataCache<ID, List<ID>> implements MutedDBI {
  MutedCache() : super('muted_list');

  final _MutedTable _table = _MutedTable();

  _MutedTask _newTask(ID user, {ID? muted, ID? allowed}) =>
      _MutedTask(mutexLock, cachePool, _table, user, muted: muted, allowed: allowed);

  @override
  Future<List<ID>> getMuteList({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  @override
  Future<bool> saveMuteList(List<ID> newContacts, {required ID user}) async {
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
        logError('failed to remove muted: $item, user: $user');
        return false;
      }
    }
    // 2. add to muted
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, muted: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to add muted: $item, user: $user');
        return false;
      }
    }

    if (count == 0) {
      logWarning('muted-list not changed: $user');
    } else {
      logInfo('updated $count muted contact(s) for user: $user');
    }

    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMuteListUpdated, this, {
      'action': 'update',
      'user': user,
      'muted_list': newContacts,
    });
    return true;
  }

  @override
  Future<bool> addMuted(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      logError('failed to get muted-list');
      return false;
    } else if (allContacts.contains(contact)) {
      logWarning('muted contact exists: $contact');
      return true;
    }
    task = _newTask(user, muted: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'add',
        'user': user,
        'muted': contact,
        'muted_list': allContacts,
      });
    }
    return ok;
  }

  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      allContacts = [];
    } else if (allContacts.contains(contact)) {
      // found
    } else {
      logWarning('muted contact not exists: $user');
      return true;
    }
    task = _newTask(user, allowed: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unmuted': contact,
        'muted_list': allContacts,
      });
    }
    return ok;
  }

}
