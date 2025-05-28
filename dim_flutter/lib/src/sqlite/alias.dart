import 'package:mutex/mutex.dart';

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

class _RemarkTask extends DatabaseTask<ID, List<ContactRemark>> {
  _RemarkTask(this._user, this._table, super.mutexLock, super.cachePool, {
    required bool? update,
  }) : _update = update;

  final ID _user;
  final bool? _update;
  final _RemarkTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<List<ContactRemark>?> readData() async {
    return await _table.getRemarks(user: _user);
  }

  @override
  Future<bool> writeData(List<ContactRemark> remarks) async {
    assert(remarks.length == 1, 'should not happen: $remarks');
    ContactRemark remark = remarks.first;
    bool? update = _update;
    if (update == null) {
      await _table.clearRemarks(remark.identifier, user: _user);
    } else if (update == true) {
      return await _table.updateRemark(remark, user: _user);
    }
    return await _table.addRemark(remark, user: _user);
  }

}

class RemarkCache with Logging implements RemarkDBI {

  final _RemarkTable _table = _RemarkTable();
  final Mutex _lock = Mutex();
  final CachePool<ID, List<ContactRemark>> _cache = CacheManager().getPool('contact_remarks');

  _RemarkTask _newTask(ID user, {bool? update}) =>
      _RemarkTask(user, _table, _lock, _cache, update: update);

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

  List<ContactRemark> _fetchRemarks(List<ContactRemark> remarks, ID contact) {
    List<ContactRemark> array = [];
    for (ContactRemark item in remarks) {
      if (item.identifier == contact) {
        array.add(item);
      }
    }
    return array;
  }

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async {
    //
    //  1. check old records
    //
    var task = _newTask(user);
    List<ContactRemark>? array = await task.load();
    if (array == null) {
      array = [];
    } else {
      array = _fetchRemarks(array, remark.identifier);
    }
    if (array.isEmpty) {
      // adding new record
      task = _newTask(user, update: false);
    } else if (array.length == 1) {
      // update old record
      task = _newTask(user, update: true);
    } else {
      logError('duplicated remarks: $user -> $array');
      task = _newTask(user, update: null);
    }
    //
    //  2. save new record
    //
    bool ok = await task.save([remark]);
    if (ok) {
      // clear to reload
      _cache.erase(user);
    } else {
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
