
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_flutter/src/common/dbi/app.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';


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


Content _extractCustomizedInfo(ResultSet resultSet, int index) {
  String json = resultSet.getString('content') ?? '';
  Content? content;
  try {
    Map? info = JSONMap.decode(json);
    content = Content.parse(info);
  } catch(e, st) {
    Log.error('failed to extract message: $json');
    Log.error('failed to extract message: $e, $st');
  }
  if (content == null) {
    // build error message
    content = TextContent.create(json);
    DateTime? time = resultSet.getDateTime('time');
    if (time != null) {
      content.setDateTime('time', time);
    }
    String? mod = resultSet.getString('mod');
    if (mod != null) {
      content['mod'] = mod;
    }
    content['error'] = 'failed to extract message';
  }
  return content;
}

class _CustomizedInfoTable extends DataTableHandler<Content> implements AppCustomizedInfoDBI {
  _CustomizedInfoTable() : super(AppCustomizedDatabase(), _extractCustomizedInfo);

  static const String _table = AppCustomizedDatabase.tCustomizedInfo;
  static const List<String> _selectColumns = ["content", "time", "mod"];
  static const List<String> _insertColumns = ["key", "content", "time", "expired", "mod"];

  static const Duration kExpires = Duration(days: 7);

  @override
  Future<bool> clearExpiredAppCustomizedContents(String key) async {
    DateTime time = DateTime.now().subtract(kExpires);
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    cond.addCondition(SQLConditions.kAnd, left: 'expired', comparison: '<', right: time);
    if (await delete(_table, conditions: cond) < 0) {
      Log.error('failed to clear expired contents: $key');
      return false;
    }
    return true;
  }

  // private
  Future<bool> clearContents(String key) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    if (await delete(_table, conditions: cond) < 0) {
      Log.error('failed to remove contents: $key');
      return false;
    }
    return true;
  }

  // private
  Future<bool> addContent(Content content, String key, {Duration? expires}) async {
    DateTime? time = content.time;
    time ??= DateTime.now();
    DateTime? expired = time.add(expires ?? kExpires);
    String? mod = content.getString('mod', null);
    // add new record
    List values = [key,
      JSON.encode(content.toMap()),
      time.millisecondsSinceEpoch ~/ 1000,
      expired.millisecondsSinceEpoch ~/ 1000,
      mod];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      Log.error('failed to save customized content: $key -> $content');
      return false;
    }
    return true;
  }

  // private
  Future<bool> updateContent(Content content, String key, {Duration? expires}) async {
    DateTime? time = content.time;
    time ??= DateTime.now();
    DateTime? expired = time.add(expires ?? kExpires);
    String? mod = content.getString('mod', null);
    // update old record
    Map<String, dynamic> values = {
      'content': JSON.encode(content.toMap()),
      'time': time.millisecondsSinceEpoch ~/ 1000,
      'expired': expired.millisecondsSinceEpoch ~/ 1000,
      'mod': mod,
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    if (await update(_table, values: values, conditions: cond) < 1) {
      Log.error('failed to update message: $key -> $content');
      return false;
    }
    return true;
  }

  // private
  Future<List<Content>> getContents(String key) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC');
  }

  @override
  Future<Content?> getAppCustomizedContent(String key, {String? mod}) async {
    List<Content> messages = await getContents(key);
    if (messages.isEmpty) {
      return null;
    } else if (mod == null || mod.isEmpty) {
      return messages.first;
    }
    for (Content content in messages) {
      if (content['mod'] == mod) {
        return content;
      }
    }
    return null;
  }

  @override
  Future<bool> saveAppCustomizedContent(Content content, String key, {Duration? expires}) async {
    // check old record
    List<Content> messages = await getContents(key);
    if (messages.length > 1) {
      logError('duplicated contents: $key -> $messages');
      await clearContents(key);
      // messages.clear();
      messages = [];
    }
    if (messages.isEmpty) {
      return await addContent(content, key, expires: expires);
    }
    return await updateContent(content, key, expires: expires);
  }

}

class CustomizedInfoCache extends _CustomizedInfoTable {

  final CachePool<String, Content> _cache = CacheManager().getPool('app_info');

  // protected
  String trimCacheKey(String key) {
    // FIXME: md5?
    if (key.length <= 64) {
      return key;
    }
    return key.substring(0, 65);
  }

  @override
  Future<Content?> getAppCustomizedContent(String key, {String? mod}) async {
    key = trimCacheKey(key);
    CachePair<Content>? pair;
    CacheHolder<Content>? holder;
    Content? value;
    double now = Time.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _cache.fetch(key, now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value == null) {
        if (holder == null) {
          // not load yet, wait to load
        } else if (holder.isAlive(now: now)) {
          // value not exists
          return null;
        } else {
          // cache expired, wait to reload
          holder.renewal(128, now: now);
        }
        // 2. load from database
        value = await super.getAppCustomizedContent(key, mod: mod);
        // update cache
        _cache.updateValue(key, value, 3600, now: now);
      }
    } finally {
      unlock();
    }
    // OK, return cache now
    if (value != null && mod != null) {
      if (value['mod'] != mod) {
        logError('content not match: $key -> $mod, $value');
        return null;
      }
    }
    return value;
  }

  @override
  Future<bool> saveAppCustomizedContent(Content content, String key, {Duration? expires}) async {
    key = trimCacheKey(key);
    // 1. do save
    if (await super.saveAppCustomizedContent(content, key, expires: expires)) {
      // clear to reload
      _cache.erase(key);
    } else {
      Log.error('failed to save content: $key -> $content');
      return false;
    }
    // 2. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kCustomizedInfoUpdated, this, {
      'key': key,
      'content': content,
    });
    return true;
  }

  @override
  Future<bool> clearExpiredAppCustomizedContents(String key) async {
    key = trimCacheKey(key);
    bool ok = await super.clearExpiredAppCustomizedContents(key);
    if (ok) {
      _cache.erase(key);
    }
    return ok;
  }

}
