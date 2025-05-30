
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
      remark.description,
    ];
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
  Future<List<ContactRemark>> loadRemarks({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC');
  }

}

class _RemarkTask extends DbTask<ID, Map<ID, ContactRemark>> {
  _RemarkTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required ContactRemark? newRemark,
  }) : _newRemark = newRemark;

  final ID _user;

  final ContactRemark? _newRemark;

  final _RemarkTable _table;

  @override
  ID get cacheKey => _user;

  @override
  Future<Map<ID, ContactRemark>?> readData() async {
    Map<ID, ContactRemark> allRemarks = {};
    List<ContactRemark> array = await _table.loadRemarks(user: _user);
    ContactRemark item;
    // convert to map: ID => ContactRemark
    for (int index = array.length - 1; index >= 0; --index) {
      item = array[index];
      allRemarks[item.identifier] = item;
    }
    return allRemarks;
  }

  @override
  Future<bool> writeData(Map<ID, ContactRemark> allRemarks) async {
    ContactRemark? remark = _newRemark;
    if (remark == null) {
      assert(false, 'should not happen: $_user');
      return false;
    }
    bool ok;
    if (allRemarks[remark.identifier] == null) {
      // record not exists
      await _table.clearRemarks(remark.identifier, user: _user);
      ok = await _table.addRemark(remark, user: _user);
    } else {
      // update old record
      ok = await _table.updateRemark(remark, user: _user);
    }
    if (ok) {
      allRemarks[remark.identifier] = remark;
    }
    return true;
  }

}

class RemarkCache extends DataCache<ID, Map<ID, ContactRemark>> implements RemarkDBI {
  RemarkCache() : super('contact_remarks');

  final _RemarkTable _table = _RemarkTable();

  _RemarkTask _newTask(ID user, {ContactRemark? newRemark}) =>
      _RemarkTask(mutexLock, cachePool, _table, user, newRemark: newRemark);

  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allRemarks = await task.load();
    return allRemarks?[contact];
  }

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async {
    //
    //  1. load old records
    //
    var task = _newTask(user);
    var allRemarks = await task.load();
    allRemarks ??= {};
    //
    //  2. save new record
    //
    task = _newTask(user, newRemark: remark);
    bool ok = await task.save(allRemarks);
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
