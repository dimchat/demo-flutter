
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_flutter/src/common/dbi/app.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';


///
///  Store app customized info
///
///     file path: '{sdcard}/Android/data/chat.dim.sechat/files/.dkd/app.db'
///


class AppCustomizedDatabase extends DatabaseConnector {
  AppCustomizedDatabase() : super(name: dbName, directory: '.dkd', version: dbVersion,
      onCreate: (db, version) {
        // customized info
        DatabaseConnector.createTable(db, tCustomizedInfo, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "key VARCHAR(64) NOT NULL UNIQUE",
          "content TEXT NOT NULL",
          "time INTEGER NOT NULL",     // time of message (seconds)
          "expired INTEGER NOT NULL",  // time to remove (seconds)
          "mod VARCHAR(32)",           // module
        ]);
        DatabaseConnector.createIndex(db, tCustomizedInfo,
            name: 'key_index', fields: ['key']);
      },
      onUpgrade: (db, oldVersion, newVersion) {
        // TODO:
      });

  static const String dbName = 'app.db';
  static const int dbVersion = 1;

  static const String tCustomizedInfo = 't_info';

}


Mapper _extractCustomizedInfo(ResultSet resultSet, int index) {
  String json = resultSet.getString('content') ?? '';
  Mapper? content;
  try {
    Map? info = JSONMap.decode(json);
    if (info != null) {
      content = Dictionary(info);
    }
  } catch(e, st) {
    Log.error('failed to extract message: $json');
    Log.error('failed to extract message: $e, $st');
  }
  if (content == null) {
    // build error message
    content = Dictionary({
      'text': json,
      'error': 'failed to extract message',
    });
    DateTime? time = resultSet.getDateTime('time');
    if (time != null) {
      content.setDateTime('time', time);
    }
    String? mod = resultSet.getString('mod');
    if (mod != null) {
      content['mod'] = mod;
    }
  }
  return content;
}

class _CustomizedInfoTable extends DataTableHandler<Mapper> {
  _CustomizedInfoTable() : super(AppCustomizedDatabase(), _extractCustomizedInfo);

  static const String _table = AppCustomizedDatabase.tCustomizedInfo;
  static const List<String> _selectColumns = ["content", "time", "mod"];
  static const List<String> _insertColumns = ["key", "content", "time", "expired", "mod"];

  static const Duration kExpires = Duration(days: 7);

  static int timestamp(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

  // protected
  Future<bool> clearExpiredContents() async {
    DateTime now = DateTime.now();
    SQLConditions cond;
    cond = SQLConditions(left: 'expired', comparison: '<', right: timestamp(now));
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to clear expired contents: $now');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> clearContents(String key) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove contents: $key');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> addContent(Mapper content, String key, {Duration? expires}) async {
    DateTime? now = DateTime.now();
    DateTime? time = content.getDateTime('time', null);
    if (time == null || time.isAfter(now)) {
      time = now;
    }
    DateTime? expired = now.add(expires ?? kExpires);
    String? mod = content.getString('mod', null);
    // add new record
    List values = [key,
      JSON.encode(content.toMap()),
      timestamp(time),
      timestamp(expired),
      mod];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to save customized content: $key -> $content');
      return false;
    }
    return true;
  }

  // protected
  Future<bool> updateContent(Mapper content, String key, {Duration? expires}) async {
    DateTime? now = DateTime.now();
    DateTime? time = content.getDateTime('time', null);
    if (time == null || time.isAfter(now)) {
      time = now;
    }
    DateTime? expired = now.add(expires ?? kExpires);
    String? mod = content.getString('mod', null);
    // update old record
    Map<String, dynamic> values = {
      'content': JSON.encode(content.toMap()),
      'time': timestamp(time),
      'expired': timestamp(expired),
      'mod': mod,
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    if (await update(_table, values: values, conditions: cond) < 1) {
      logError('failed to update message: $key -> $content');
      return false;
    }
    return true;
  }

  // protected
  Future<List<Mapper>> getContents(String key) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC');
  }

}

class _CustomizedTask extends DbTask<String, List<Mapper>> {
  _CustomizedTask(super.mutexLock, super.cachePool, this._table, this._cacheKey, {
    required bool? update,
    required Duration? expires,
  }) : _update = update, _dataExpires = expires;

  final String _cacheKey;

  final bool? _update;
  final Duration? _dataExpires;

  final _CustomizedInfoTable _table;

  @override
  String get cacheKey => _cacheKey;

  @override
  Future<List<Mapper>?> readData() async {
    List<Mapper> array = await _table.getContents(_cacheKey);
    assert(array.length <= 1, 'duplicated contents: $_cacheKey -> $array');
    return array;
  }

  @override
  Future<bool> writeData(List<Mapper> contents) async {
    assert(contents.length == 1, 'should not happen: $contents');
    bool? update = _update;
    if (update == null) {
      // duplicated records found, clear all
      await _table.clearContents(_cacheKey);
    } else if (update == true) {
      // update old record
      return await _table.updateContent(contents.first, _cacheKey, expires: _dataExpires);
    }
    // insert new record
    return await _table.addContent(contents.first, _cacheKey, expires: _dataExpires);
  }

}

class CustomizedInfoCache extends DataCache<String, List<Mapper>> implements AppCustomizedInfoDBI {
  CustomizedInfoCache() : super('app_info');

  final _CustomizedInfoTable _table = _CustomizedInfoTable();

  _CustomizedTask _newTask(String key, {bool? update, Duration? expires}) =>
      _CustomizedTask(mutexLock, cachePool, _table, key, update: update, expires: expires);

  @override
  Future<Mapper?> getAppCustomizedInfo(String key, {String? mod}) async {
    var task = _newTask(key);
    List<Mapper>? array = await task.load();
    if (array == null || array.isEmpty) {
      // data not found
      return null;
    } else if (mod == null || mod.isEmpty) {
      return array.first;
    }
    for (Mapper content in array) {
      if (content['mod'] == mod) {
        return content;
      }
      logError('content not match: $key -> $mod, $content');
    }
    // data not matched
    return null;
  }

  @override
  Future<bool> saveAppCustomizedInfo(Mapper content, String key, {Duration? expires}) async {
    //
    //  1. check old records
    //
    var task = _newTask(key);
    List<Mapper>? array = await task.load();
    if (array == null || array.isEmpty) {
      // adding new record
      task = _newTask(key, update: false, expires: expires);
    } else {
      // check time
      DateTime? newTime = content.getDateTime('time', null);
      if (newTime != null) {
        Mapper old = array.first;
        DateTime? oldTime = old.getDateTime('time', null);
        if (oldTime != null && oldTime.isAfter(newTime)) {
          logWarning('ignore expired info: $content');
          return false;
        }
      }
      if (array.length == 1) {
        // update old record
        task = _newTask(key, update: true, expires: expires);
      } else {
        logError('duplicated contents: $key -> $array');
        task = _newTask(key, update: null, expires: expires);
      }
    }
    //
    //  2. save new record
    //
    bool ok = await task.save([content]);
    if (!ok) {
      logError('failed to save content: $key -> $content');
      return false;
    }
    //
    //  3. post notification
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kCustomizedInfoUpdated, this, {
      'key': key,
      'info': content,
    });
    return true;
  }

  @override
  Future<bool> clearExpiredAppCustomizedInfo() async {
    bool ok;
    await mutexLock.acquire();
    try {
      ok = await _table.clearExpiredContents();
      if (ok) {
        cachePool.purge();
      }
    } finally {
      mutexLock.release();
    }
    return ok;
  }

}
