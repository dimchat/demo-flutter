
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';

import 'entity.dart';


Pair<GroupCommand, ReliableMessage> _extractCommandMessage(ResultSet resultSet, int index) {
  Map? content = JSONMap.decode(resultSet.getString('content')!);
  Map? message = JSONMap.decode(resultSet.getString('message')!);
  return Pair(Command.parse(content) as GroupCommand, ReliableMessage.parse(message)!);
}


class _GroupHistoryTable extends DataTableHandler<Pair<GroupCommand, ReliableMessage>> implements GroupHistoryDBI {
  _GroupHistoryTable() : super(GroupDatabase(), _extractCommandMessage);

  static const String _table = GroupDatabase.tHistory;
  static const List<String> _selectColumns = ["content", "message"];
  static const List<String> _insertColumns = ["gid", "cmd", "time", "content", "message"];

  @override
  Future<bool> saveGroupHistory(GroupCommand content, ReliableMessage rMsg, {required ID group}) async {
    String cmd = content.cmd;
    DateTime? time = content.time;
    int seconds = time == null ? 0 : time.millisecondsSinceEpoch ~/ 1000;
    String command = JSON.encode(content.toMap());
    String message = JSON.encode(rMsg.toMap());
    List values = [group.toString(), cmd, seconds, command, message];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'cmd', comparison: '=', right: 'reset');
    List<Pair<GroupCommand, ReliableMessage>> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    if (array.isNotEmpty) {
      var pair = array.first;
      GroupCommand content = pair.first;
      ReliableMessage message = pair.second;
      if (content is ResetCommand) {
        return Pair(content, message);
      }
      assert(false, 'group command error: $group, $content');
    }
    // assert(false, 'group command error: $group, $array');
    return const Pair(null, null);
  }

  @override
  Future<bool> clearGroupAdminHistories({required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'cmd', comparison: '=', right: 'resign');
    return await delete(_table, conditions: cond) >= 0;
  }

  @override
  Future<bool> clearGroupMemberHistories({required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'cmd', comparison: '<>', right: 'resign');
    return await delete(_table, conditions: cond) >= 0;
  }

}

class GroupHistoryCache extends _GroupHistoryTable {
  GroupHistoryCache() {
    _historyCache = CacheManager().getPool('group_history');
    _resetCache = CacheManager().getPool('group_reset');
  }

  late final CachePool<ID, List<Pair<GroupCommand, ReliableMessage>>> _historyCache;
  late final CachePool<ID, Pair<ResetCommand?, ReliableMessage?>> _resetCache;

  @override
  Future<bool> saveGroupHistory(GroupCommand content, ReliableMessage rMsg, {required ID group}) async {
    // 1. add new record
    if (await super.saveGroupHistory(content, rMsg, group: group)) {
      // 2. clear to reload
      _historyCache.erase(group);
      _resetCache.erase(group);
    } else {
      Log.error('failed to save group command: $group');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kGroupHistoryUpdated, this, {
      'ID': group,
      'content': content,
      'message': rMsg,
    });
    return true;
  }

  @override
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({required ID group}) async {
    CachePair<List<Pair<GroupCommand, ReliableMessage>>>? pair;
    CacheHolder<List<Pair<GroupCommand, ReliableMessage>>>? holder;
    List<Pair<GroupCommand, ReliableMessage>>? value;
    double now = TimeUtils.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _historyCache.fetch(group, now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value == null) {
        if (holder == null) {
          // not load yet, wait to load
        } else if (holder.isAlive(now: now)) {
          // value not exists
          return [];
        } else {
          // cache expired, wait to reload
          holder.renewal(128, now: now);
        }
        // 2. load from database
        value = await super.getGroupHistories(group: group);
        // update cache
        _historyCache.updateValue(group, value, 3600, now: now);
      }
    } finally {
      unlock();
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group}) async {
    CachePair<Pair<ResetCommand?, ReliableMessage?>>? pair;
    CacheHolder<Pair<ResetCommand?, ReliableMessage?>>? holder;
    Pair<ResetCommand?, ReliableMessage?>? value;
    double now = TimeUtils.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _resetCache.fetch(group, now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value == null) {
        if (holder == null) {
          // not load yet, wait to load
        } else if (holder.isAlive(now: now)) {
          // value not exists
          return const Pair(null, null);
        } else {
          // cache expired, wait to reload
          holder.renewal(128, now: now);
        }
        // 2. load from database
        value = await super.getResetCommandMessage(group: group);
        // update cache
        _resetCache.updateValue(group, value, 3600, now: now);
      }
    } finally {
      unlock();
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> clearGroupAdminHistories({required ID group}) async {
    if (await super.clearGroupAdminHistories(group: group)) {
      // clear for reload
      _historyCache.erase(group);
    } else {
      Log.error('failed to remove history for group: $group');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kGroupHistoryUpdated, this, {
      'ID': group,
    });
    return true;
  }

  @override
  Future<bool> clearGroupMemberHistories({required ID group}) async {
    if (await super.clearGroupMemberHistories(group: group)) {
      // clear for reload
      _historyCache.erase(group);
      _resetCache.erase(group);
    } else {
      Log.error('failed to remove history for group: $group');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kGroupHistoryUpdated, this, {
      'ID': group,
    });
    return true;
  }

}
