import 'helper/sqlite.dart';
import 'message.dart';

abstract class TraceDBI {

  ///  Get traces for message
  ///
  /// @param sender    - message's sender
  /// @param sn        - message's serial number
  /// @param signature - message's signature
  /// @return MTA list
  Future<List<String>> getTraces(ID sender, int sn, String? signature);

  ///  Save message trace (response)
  ///
  /// @param trace     - response: '{"ID": "{MTA_ID}", "time": 0}'
  /// @param cid       - conversation ID
  /// @param sender    - original message's sender
  /// @param sn        - original message's serial number
  /// @param signature - original message's signature (last 8 characters)
  /// @return false on error
  Future<bool> addTrace(String trace, ID cid,
      {required ID sender, required int sn, required String? signature});

  ///  Remove traces for message
  ///  (call when message delete)
  ///
  /// @param sender    - message's sender
  /// @param sn        - message's serial number
  /// @param signature - message's signature
  /// @return false on error
  Future<bool> removeTraces(ID sender, int sn, String? signature);

  ///  Remove all traces in the conversation
  ///  (call when conversation cleared)
  ///
  /// @param cid       - conversation ID
  /// @return false on error
  Future<bool> removeAllTraces(ID cid);

}

String _extractTrace(ResultSet resultSet, int index) {
  return resultSet.getString('trace');
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
    List values = [cid.string, sender.string, sn, signature, trace];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<List<String>> getTraces(ID sender, int sn, String? signature) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'sender', comparison: '=', right: sender.string);
    cond.addCondition(SQLConditions.kAnd, left: 'sn', comparison: '=', right: sn);
    if (signature != null) {
      if (signature.length > 8) {
        signature = signature.substring(signature.length - 8);
      }
      cond.addCondition(SQLConditions.kAnd,
          left: 'signature', comparison: '=', right: signature);
    }
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<bool> removeTraces(ID sender, int sn, String? signature) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'sender', comparison: '=', right: sender.string);
    cond.addCondition(SQLConditions.kAnd, left: 'sn', comparison: '=', right: sn);
    if (signature != null) {
      if (signature.length > 8) {
        signature = signature.substring(signature.length - 8);
      }
      cond.addCondition(SQLConditions.kAnd,
          left: 'signature', comparison: '=', right: signature);
    }
    return await delete(_table, conditions: cond) > 0;
  }

  @override
  Future<bool> removeAllTraces(ID cid) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: cid.string);
    return await delete(_table, conditions: cond) > 0;
  }

}
