import '../client/constants.dart';
import 'entity.dart';
import 'helper/sqlite.dart';


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

class MetaTable extends DataTableHandler<Meta> implements MetaDBI {
  MetaTable() : super(EntityDatabase(), _extractMeta);

  static const String _table = EntityDatabase.tMeta;
  static const List<String> _selectColumns = ["type", "pub_key", "seed", "fingerprint"];
  static const List<String> _insertColumns = ["did", "type", "pub_key", "seed", "fingerprint"];

  @override
  Future<Meta?> getMeta(ID entity) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.string);
    List<Meta> array = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);
    // first record only
    return array.isEmpty ? null : array[0];
  }

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    int type = meta.type;
    String json = JSON.encode(meta.key.dictionary);
    String seed;
    String fingerprint;
    if (MetaType.hasSeed(type)) {
      seed = meta.seed!;
      fingerprint = meta.getString('fingerprint')!;
    } else {
      seed = '';
      fingerprint = '';
    }
    List values = [entity.string, type, json, seed, fingerprint];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class MetaCache extends MetaTable {

  final CachePool<ID, Meta> _cache = CacheManager().getPool('meta');

  @override
  Future<Meta?> getMeta(ID entity) async {
    int now = Time.currentTimeMillis;
    // 1. check memory cache
    CachePair<Meta>? pair = _cache.fetch(entity, now: now);
    CacheHolder<Meta>? holder = pair?.holder;
    Meta? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
        _cache.update(entity, value: null, life: 128 * 1000, now: now);
      } else {
        if (holder.isAlive(now: now)) {
          // value not exists
          return null;
        }
        // cache expired, wait to reload
        holder.renewal(duration: 128 * 1000, now: now);
      }
      // 2. load from database
      value = await super.getMeta(entity);
      // update cache
      _cache.update(entity, value: value, life: 36000 * 1000, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    // 0. check valid
    if (!Meta.matchID(entity, meta)) {
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
      _cache.update(entity, value: meta, life: 36000 * 1000);
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

}
