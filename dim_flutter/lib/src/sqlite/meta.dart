
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';

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
  if (MetaType.hasSeed(type!)) {
    info['seed'] = resultSet.getString('seed');
    info['fingerprint'] = resultSet.getString('fingerprint');
  }
  return Meta.parse(info)!;
}

class _MetaTable extends DataTableHandler<Meta> implements MetaDBI {
  _MetaTable() : super(EntityDatabase(), _extractMeta);

  static const String _table = EntityDatabase.tMeta;
  static const List<String> _selectColumns = ["type", "pub_key", "seed", "fingerprint"];
  static const List<String> _insertColumns = ["did", "type", "pub_key", "seed", "fingerprint"];

  @override
  Future<Meta?> getMeta(ID entity) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.toString());
    List<Meta> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    return array.isEmpty ? null : array.first;
  }

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    int type = MetaType.parseInt(meta.type, 0);
    String json = JSON.encode(meta.publicKey.toMap());
    String seed;
    String fingerprint;
    if (MetaType.hasSeed(type)) {
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

class MetaCache extends _MetaTable {

  final CachePool<ID, Meta> _cache = CacheManager().getPool('meta');

  @override
  Future<Meta?> getMeta(ID entity) async {
    CachePair<Meta>? pair;
    CacheHolder<Meta>? holder;
    Meta? value;
    double now = Time.currentTimeSeconds;
    await lock();
    try {
      // 1. check memory cache
      pair = _cache.fetch(entity, now: now);
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
        value = await super.getMeta(entity);
        // update cache
        _cache.updateValue(entity, value, 36000, now: now);
      }
    } finally {
      unlock();
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    // 0. check valid
    if (!checkMeta(meta, entity)) {
      Log.error('meta not match: $entity');
      return false;
    }
    // 1. check old record
    Meta? old = await getMeta(entity);
    if (old != null) {
      // meta won't change, so no need to update it here
      Log.warning('meta exists: $entity');
      return true;
    }
    // 2. save to database
    if (await super.saveMeta(meta, entity)) {
      // update cache
      _cache.updateValue(entity, meta, 36000, now: Time.currentTimeSeconds);
    } else {
      Log.error('failed to save meta: $entity');
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
