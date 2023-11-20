import 'package:lnc/lnc.dart';

import '../common/dbi/message.dart';

import 'helper/sqlite.dart';
import 'message.dart';

String _extractTrace(ResultSet resultSet, int index) {
  return resultSet.getString('trace')!;
}

class TraceTable extends DataTableHandler<String> implements TraceDBI {
  TraceTable() : super(MessageDatabase(), _extractTrace);

  static const String _table = MessageDatabase.tTrace;
  static const List<String> _selectColumns = ["trace"];
  static const List<String> _insertColumns = ["cid", "sender", "sn", "signature", "trace"];

  @override
  Future<bool> addTrace(String trace, ID cid,
      {required ID sender, required int sn, required String? signature}) async {
    if (signature == null) {
      signature = '';
    } else if (signature.length > 8) {
      signature = signature.substring(signature.length - 8);
    }
    List values = [cid.toString(), sender.toString(), sn, signature, trace];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<List<String>> getTraces(ID sender, int sn, String? signature) async {
    SQLConditions cond;
    if (signature != null) {
      if (signature.length > 8) {
        signature = signature.substring(signature.length - 8);
      }
      cond = SQLConditions(left: 'signature', comparison: '=', right: signature);
      if (sn > 0) {
        cond.addCondition(SQLConditions.kOr, left: 'sn', comparison: '=', right: sn);
      }
    } else if (sn > 0) {
      cond = SQLConditions(left: 'sn', comparison: '=', right: sn);
    } else {
      Log.error('failed to get trace without sn or signature: $sender');
      return [];
    }
    cond.addCondition(SQLConditions.kAnd,
        left: 'sender', comparison: '=', right: sender.toString());
    // SELECT * FROM t_trace WHERE (signature='...' OR sn='123') AND sender='abc'
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<bool> removeTraces(ID sender, int sn, String? signature) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'sender', comparison: '=', right: sender.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'sn', comparison: '=', right: sn);
    if (signature != null) {
      if (signature.length > 8) {
        signature = signature.substring(signature.length - 8);
      }
      cond.addCondition(SQLConditions.kAnd,
          left: 'signature', comparison: '=', right: signature);
    }
    return await delete(_table, conditions: cond) >= 0;
  }

  @override
  Future<bool> removeAllTraces(ID cid) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: cid.toString());
    return await delete(_table, conditions: cond) >= 0;
  }

}
