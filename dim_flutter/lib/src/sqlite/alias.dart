
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/dbi/contact.dart';
import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


ContactRemark _extractRemark(ResultSet resultSet, int index) {
  String? cid = resultSet.getString('contact');
  String? alias = resultSet.getString('alias');
  String? desc = resultSet.getString('description');
  ID contact = ID.parse(cid)!;
  return ContactRemark(contact, alias: alias ?? '', description: desc ?? '');
}

class _RemarkTable extends DataTableHandler<ContactRemark> {
  _RemarkTable() : super(EntityDatabase(), _extractRemark);

  static const String _table = EntityDatabase.tRemark;
  static const List<String> _selectColumns = ["contact", "alias", "description"];
  static const List<String> _insertColumns = ["uid", "contact", "alias", "description"];

  // protected
  Future<bool> clearRemarks(ID contact, {required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'contact', comparison: '=', right: contact.toString());
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove remarks: $user -> $contact');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addRemark(ContactRemark remark, {required ID user}) async {
    // add new record
    List values = [
      user.toString(),
      remark.identifier.toString(),
      remark.alias,
      remark.description];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to save remark: $user -> $remark');
      return false;
    }
    return true;
  }

  Future<bool> updateRemark(ContactRemark remark, {required ID user}) async {
    // update old record
    Map<String, dynamic> values = {
      'alias': remark.alias,
      'description': remark.description,
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'contact', comparison: '=', right: remark.identifier.toString());
    if (await update(_table, values: values, conditions: cond) < 1) {
      logError('failed to update remark: $user -> $remark');
      return false;
    }
    return true;
  }

  // protected
  Future<List<ContactRemark>> getRemarks({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC');
  }

}

class _RemarkTask extends DbTask<ID, List<ContactRemark>> {
  _RemarkTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required bool? update,
    required ContactRemark? newRemark,
  }) : _update = update, _newRemark = newRemark;

  final ID _user;

  final bool? _update;
  final ContactRemark? _newRemark;

  final _RemarkTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ContactRemark>?> readData() async {
    return await _table.getRemarks(user: _user);
  }

  @override
  Future<bool> writeData(List<ContactRemark> allRemarks) async {
    assert(allRemarks.isNotEmpty, 'remark list should not empty here: $_user');
    ContactRemark? remark = _newRemark;
    if (remark == null) {
      assert(false, 'should not happen: $_user, $remark');
      return false;
    }
    bool? update = _update;
    if (update == null) {
      // duplicated records found, clear all
      await _table.clearRemarks(remark.identifier, user: _user);
    } else if (update == true) {
      // update old record
      return await _table.updateRemark(remark, user: _user);
    }
    // insert new record
    return await _table.addRemark(remark, user: _user);
  }

}

class RemarkCache extends DataCache<ID, List<ContactRemark>> implements RemarkDBI {
  RemarkCache() : super('contact_remarks');

  final _RemarkTable _table = _RemarkTable();

  _RemarkTask _newTask(ID user, {bool? update, ContactRemark? newRemark}) =>
      _RemarkTask(mutexLock, cachePool, _table, user, update: update, newRemark: newRemark);

  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async {
    var task = _newTask(user);
    List<ContactRemark>? remarks = await task.load();
    if (remarks == null || remarks.isEmpty) {
      // data not found
      return null;
    }
    for (ContactRemark item in remarks) {
      if (item.identifier == contact) {
        return item;
      }
    }
    // data not matched
    return null;
  }

  List<ContactRemark> _shiftRemarks(List<ContactRemark> allRemarks, ContactRemark newRemark) {
    List<ContactRemark> array = [];
    ContactRemark item;
    for (int index = allRemarks.length - 1; index >= 0; --index) {
      item = allRemarks[index];
      if (item.identifier == newRemark.identifier) {
        // remove old records
        array.add(item);
        allRemarks.removeAt(index);
      }
    }
    // add new record
    allRemarks.add(newRemark);
    return array;
  }

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async {
    //
    //  1. check old records
    //
    var task = _newTask(user);
    List<ContactRemark>? array = await task.load();
    List<ContactRemark> old;
    if (array == null) {
      array = [remark];
      old = [];
    } else {
      old = _shiftRemarks(array, remark);
    }
    if (old.isEmpty) {
      // adding new record
      task = _newTask(user, update: false, newRemark: remark);
    } else if (old.length == 1) {
      // update old record
      task = _newTask(user, update: true, newRemark: remark);
    } else {
      logError('duplicated remarks: $user -> $old');
      task = _newTask(user, update: null, newRemark: remark);
    }
    //
    //  2. save new record
    //
    bool ok = await task.save(array);
    if (!ok) {
      logError('failed to save remark: $user -> $remark');
      return false;
    }
    //
    //  3. post notification
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kRemarkUpdated, this, {
      'user': user,
      'contact': remark.identifier,
      'remark': remark,
    });
    return true;
  }

}
