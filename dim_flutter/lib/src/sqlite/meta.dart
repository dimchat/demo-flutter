
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


Meta _extractMeta(ResultSet resultSet, int index) {
  int? type = resultSet.getInt('type');
  String? json = resultSet.getString('pub_key');
  Map? key = JSON.decode(json!);

  Map info = {
    'version': type,
    'type': type,
    'key': key,
  };
  if (MetaVersion.hasSeed(type!)) {
    info['seed'] = resultSet.getString('seed');
    info['fingerprint'] = resultSet.getString('fingerprint');
  }
  return Meta.parse(info)!;
}

class _MetaTable extends DataTableHandler<Meta> {
  _MetaTable() : super(EntityDatabase(), _extractMeta);

  static const String _table = EntityDatabase.tMeta;
  static const List<String> _selectColumns = ["type", "pub_key", "seed", "fingerprint"];
  static const List<String> _insertColumns = ["did", "type", "pub_key", "seed", "fingerprint"];

  Future<Meta?> loadMeta(ID entity) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.toString());
    List<Meta> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    return array.isEmpty ? null : array.first;
  }

  Future<bool> saveMeta(Meta meta, ID entity) async {
    int type = MetaVersion.parseInt(meta.type, 0);
    String json = JSON.encode(meta.publicKey.toMap());
    String seed;
    String fingerprint;
    if (MetaVersion.hasSeed(type)) {
      seed = meta.seed!;
      fingerprint = meta.getString('fingerprint', '')!;
    } else {
      seed = '';
      fingerprint = '';
    }
    List values = [entity.toString(), type, json, seed, fingerprint];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class _MetaTask extends DbTask<ID, Meta> {
  _MetaTask(super.mutexLock, super.cachePool, this._table, this._entity)
      : super(cacheExpires: 36000, cacheRefresh: 128);

  final ID _entity;
  final _MetaTable _table;

  @override
  ID get cacheKey => _entity;

  @override
  Future<Meta?> readData() async => await _table.loadMeta(_entity);

  @override
  Future<bool> writeData(Meta meta) async => await _table.saveMeta(meta, _entity);

}

class MetaCache extends DataCache<ID, Meta> implements MetaDBI {
  MetaCache() : super('meta');

  final _MetaTable _table = _MetaTable();

  _MetaTask _newTask(ID entity) => _MetaTask(mutexLock, cachePool, _table, entity);

  @override
  Future<Meta?> getMeta(ID entity) async {
    var task = _newTask(entity);
    return await task.load();
  }

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    // 0. check valid
    if (!checkMeta(meta, entity)) {
      logError('meta not match: $entity');
      return false;
    }
    // 1. check old record
    Meta? old = await getMeta(entity);
    if (old != null) {
      // meta won't change, so no need to update it here
      logWarning('meta exists: $entity');
      return true;
    }
    // 2. save to database
    var task = _newTask(entity);
    var ok = await task.save(meta);
    if (!ok) {
      logError('failed to save meta: $entity');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMetaSaved, this, {
      'ID': entity,
      'meta': meta,
    });
    return true;
  }

  bool checkMeta(Meta meta, ID identifier) {
    return meta.isValid && MetaUtils.matchIdentifier(identifier, meta);
  }

}
