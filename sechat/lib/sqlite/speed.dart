import 'package:dim_client/dim_client.dart';

import 'helper/handler.dart';
import 'service.dart';

abstract class SpeedDBI {

  Future<List<Triplet<Pair<String, int>, ID, Pair<DateTime, double>>>>
  getSpeeds(String host, int port);

  Future<bool> addSpeed(String host, int port,
      {required ID identifier, required DateTime time, required double duration});

  Future<bool> removeExpired(DateTime? expired);

}

/// Speed test result: ((host, port), sid, (test_time, response_time))
typedef _SpeedInfo = Triplet<Pair<String, int>, ID, Pair<DateTime, double>>;

_SpeedInfo _extractSpeed(ResultSet resultSet, int index) {
  String? host = resultSet.getString('host');
  int? port = resultSet.getInt('port');
  String? sid = resultSet.getString('sid');
  DateTime? time = resultSet.getTime('time');
  double? duration = resultSet.getDouble('duration');
  return Triplet(Pair(host!, port!), ID.parse(sid)!, Pair(time!, duration!));
}

class SpeedTable extends DataTableHandler<_SpeedInfo> implements SpeedDBI {
  SpeedTable() : super(ServiceProviderDatabase(), _extractSpeed);

  static const String _table = ServiceProviderDatabase.tSpeed;
  static const List<String> _selectColumns = ["host", "port", "sid", "time", "duration"];
  static const List<String> _insertColumns = ["host", "port", "sid", "time", "duration"];

  @override
  Future<List<Triplet<Pair<String, int>, ID, Pair<DateTime, double>>>>
  getSpeeds(String host, int port) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd,
        left: 'port', comparison: '=', right: port);
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC');
  }

  @override
  Future<bool> addSpeed(String host, int port,
      {required ID identifier, required DateTime time, required double duration}) async {
    int seconds = time.millisecondsSinceEpoch ~/ 1000;
    List values = [host, port, identifier.string, seconds, duration];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> removeExpired(DateTime? expired) async {
    int time;
    if (expired == null) {
      time = Time.currentTimeMillis ~/ 1000 - 72 * 3600;
    } else {
      time = expired.millisecondsSinceEpoch ~/ 1000;
    }
    SQLConditions cond;
    cond = SQLConditions(left: 'time', comparison: '<', right: time);
    return await delete(_table, conditions: cond) > 0;
  }

}