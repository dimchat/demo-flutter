import 'package:lnc/lnc.dart';

import '../client/constants.dart';
import 'helper/sqlite.dart';


///
///  Store reset group command messages
///
///     file path: '/data/data/chat.dim.sechat/databases/group.db'
///


class GroupDatabase extends DatabaseConnector {
  GroupDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) {
        // reset group command
        DatabaseConnector.createTable(db, tResetGroup, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "gid VARCHAR(64) NOT NULL",
          "cmd TEXT NOT NULL",
          "msg TEXT NOT NULL",
        ]);
        DatabaseConnector.createIndex(db, tResetGroup,
            name: 'gid_index', fields: ['gid']);
      }, onUpgrade: (db, oldVersion, newVersion) {
        // TODO:
      });

  static const String dbName = 'group.db';
  static const int dbVersion = 1;

  static const String tResetGroup    = 't_reset_group';

}


Pair<ResetCommand, ReliableMessage> _extractCommandMessage(ResultSet resultSet, int index) {
  Map? cmd = JSONMap.decode(resultSet.getString('cmd')!);
  Map? msg = JSONMap.decode(resultSet.getString('msg')!);
  return Pair(Command.parse(cmd) as ResetCommand, ReliableMessage.parse(msg)!);
}


class _ResetCommandTable extends DataTableHandler<Pair<ResetCommand, ReliableMessage>> implements ResetGroupDBI {
  _ResetCommandTable() : super(GroupDatabase(), _extractCommandMessage);

  static const String _table = GroupDatabase.tResetGroup;
  static const List<String> _selectColumns = ["cmd", "msg"];
  static const List<String> _insertColumns = ["gid", "cmd", "msg"];

  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    List<Pair<ResetCommand, ReliableMessage>> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    return array.isEmpty ? const Pair(null, null) : array[0];
  }

  Future<bool> deleteResetCommandMessage(ID identifier) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: identifier.toString());
    return await delete(_table, conditions: cond) > 0;
  }

  @override
  Future<bool> saveResetCommandMessage(ResetCommand content, ReliableMessage rMsg, {required ID group}) async {
    String cmd = JSON.encode(content.toMap());
    String msg = JSON.encode(rMsg.toMap());
    List values = [group.toString(), cmd, msg];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class ResetCommandCache extends _ResetCommandTable {
  ResetCommandCache() {
    _cache = CacheManager().getPool('reset_group_command');
  }

  late final CachePool<ID, Pair<ResetCommand?, ReliableMessage?>> _cache;

  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group}) async {
    double now = Time.currentTimeSeconds;
    // 1. check memory cache
    CachePair<Pair<ResetCommand?, ReliableMessage?>>? pair;
    pair = _cache.fetch(group, now: now);
    if (pair == null) {
      // maybe another thread is trying to load data,
      // so wait a while to check it again.
      await randomWait();
      pair = _cache.fetch(group, now: now);
    }
    CacheHolder<Pair<ResetCommand?, ReliableMessage?>>? holder = pair?.holder;
    Pair<ResetCommand?, ReliableMessage?>? value = pair?.value;
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
      _cache.updateValue(group, value, 3600, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveResetCommandMessage(ResetCommand content, ReliableMessage rMsg, {required ID group}) async {
    // 1. check old record
    ResetCommand? old = (await getResetCommandMessage(group: group)).first;
    if (AccountDBI.isExpired(content.time, old?.time)) {
      Log.warning('expired command: $group');
      return false;
    }
    // 2. clear old records
    if (old != null) {
      if (await deleteResetCommandMessage(group)) {
        Log.debug('old reset group command cleared: $group');
        // clear to reload
        _cache.erase(group);
      } else {
        Log.error('failed to clear reset group command: $group');
        return false;
      }
    }
    // 3. add new record
    if (await super.saveResetCommandMessage(content, rMsg, group: group)) {
      // clear to reload
      _cache.erase(group);
    } else {
      Log.error('failed to save reset group command: $group');
      return false;
    }
    // 4. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kResetGroupCommandUpdated, this, {
      'ID': group,
      'cmd': content,
      'msg': rMsg,
    });
    return true;
  }

}
