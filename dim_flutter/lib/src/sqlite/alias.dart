import 'package:lnc/lnc.dart';

import '../common/dbi/contact.dart';
import '../client/constants.dart';
import 'helper/sqlite.dart';
import 'entity.dart';


ContactRemark _extractRemark(ResultSet resultSet, int index) {
  String? cid = resultSet.getString('contact');
  String? alias = resultSet.getString('alias');
  String? desc = resultSet.getString('description');
  ID contact = ID.parse(cid)!;
  return ContactRemark(contact, alias: alias ?? '', description: desc ?? '');
}

class _RemarkTable extends DataTableHandler<ContactRemark> implements RemarkDBI {
  _RemarkTable() : super(EntityDatabase(), _extractRemark);

  static const String _table = EntityDatabase.tRemark;
  static const List<String> _selectColumns = ["contact", "alias", "description"];
  static const List<String> _insertColumns = ["uid", "contact", "alias", "description"];

  @override
  Future<List<ContactRemark>> allRemarks({required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'contact', comparison: '=', right: contact.toString());
    List<ContactRemark> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    return array.isEmpty ? null : array.first;
  }

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async {
    SQLConditions cond;
    List<ContactRemark> array = await allRemarks(user: user);
    for (ContactRemark item in array) {
      if (item.identifier == remark.identifier) {
        // update record
        cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
        cond.addCondition(SQLConditions.kAnd,
            left: 'contact', comparison: '=', right: item.identifier.toString());
        Map<String, dynamic> values = {
          'alias': item.alias,
          'description': item.description,
        };
        return await update(_table, values: values, conditions: cond) > 0;
      }
    }
    // add new record
    List values = [user.toString(), remark.identifier.toString(),
      remark.alias, remark.description];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class RemarkCache extends _RemarkTable {

  final Map<ID, List<ContactRemark>> _caches = {};

  @override
  Future<List<ContactRemark>> allRemarks({required ID user}) async {
    List<ContactRemark>? array = _caches[user];
    if (array == null) {
      // cache not found, try to load from database
      array = await super.allRemarks(user: user);
      // add to cache
      _caches[user] = array;
    }
    return array;
  }

  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async {
    List<ContactRemark>? array = await allRemarks(user: user);
    for (ContactRemark item in array) {
      if (item.identifier == contact) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async {
    bool ok = await super.setRemark(remark, user: user);
    if (ok) {
      // clear to reload
      _caches.remove(user);
      // post notification
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kRemarkUpdated, this, {
        'user': user,
        'contact': remark.identifier,
        'remark': remark,
      });
    }
    return ok;
  }

}
