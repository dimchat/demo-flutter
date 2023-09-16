import 'dart:io';

import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../client/constants.dart';
import 'helper/sqlite.dart';


///
///  Store private keys
///
///     file path: '/data/data/chat.dim.sechat/databases/key.db'
///


class CryptoKeyDatabase extends DatabaseConnector {
  CryptoKeyDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) {
        // private key
        DatabaseConnector.createTable(db, tPrivateKey, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "uid VARCHAR(64) NOT NULL",
          "pri_key TEXT NOT NULL",
          "type CHAR(1)",
          "sign BIT",
          "decrypt BIT",
        ]);
        DatabaseConnector.createIndex(db, tPrivateKey,
            name: 'user_id_index', fields: ['uid']);
        // // msg key
        // DatabaseConnector.createTable(db, tMsgKey, fields: [
        //   "id INTEGER PRIMARY KEY AUTOINCREMENT",
        //   "sender VARCHAR(64) NOT NULL",
        //   "receiver VARCHAR(64) NOT NULL",
        //   "pwd TEXT NOT NULL",
        // ]);
        // DatabaseConnector.createIndex(db, tMsgKey,
        //     name: 'direction_index', fields: ['sender', 'receiver']);
      });

  static const String dbName = 'key.db';
  static const int dbVersion = 1;

  static const String tPrivateKey = 't_private_key';
  // static const String tMsgKey     = 't_msg_key';

}


PrivateKey _extractPrivateKey(ResultSet resultSet, int index) {
  String? json = resultSet.getString('pri_key');
  Map? info = JSON.decode(json!);
  return PrivateKey.parse(info)!;
}

class _PrivateKeyTable extends DataTableHandler<PrivateKey> implements PrivateKeyDBI {
  _PrivateKeyTable() : super(CryptoKeyDatabase(), _extractPrivateKey);

  static const String _table = CryptoKeyDatabase.tPrivateKey;
  static const List<String> _selectColumns = ["pri_key"];
  static const List<String> _insertColumns = ["uid", "pri_key", "type", "sign", "decrypt"];

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    if (Platform.isIOS || Platform.isMacOS) {
      ChannelManager man = ChannelManager();
      return await man.dbChannel.getPrivateKeysForDecryption(user);
    }
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'decrypt', comparison: '<>', right: 0);
    // WHERE uid='$user' AND decrypt=1 ORDER BY type DESC LIMIT 3
    List<PrivateKey> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'type DESC, id DESC', limit: 3);
    return PrivateKeyDBI.convertDecryptKeys(array);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async {
    if (Platform.isIOS || Platform.isMacOS) {
      ChannelManager man = ChannelManager();
      return await man.dbChannel.getPrivateKeyForSignature(user);
    }
    // TODO: support multi private keys
    return await getPrivateKeyForVisaSignature(user);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    if (Platform.isIOS || Platform.isMacOS) {
      ChannelManager man = ChannelManager();
      return await man.dbChannel.getPrivateKeyForVisaSignature(user);
    }
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'type', comparison: '=', right: PrivateKeyDBI.kMeta);
    cond.addCondition(SQLConditions.kAnd, left: 'sign', comparison: '<>', right: 0);
    // WHERE uid='$user' AND type='M' AND decrypt=1 ORDER BY id DESC  LIMIT 1
    List<PrivateKey> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // first record only
    return array.isEmpty ? null : array[0];
  }

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async {
    if (Platform.isIOS || Platform.isMacOS) {
      ChannelManager man = ChannelManager();
      return await man.dbChannel.savePrivateKey(key, type, user,
          sign: sign, decrypt: decrypt);
    }
    // 1. save to database
    String json = JSON.encode(key.toMap());
    List values = [user.toString(), json, type, sign, decrypt];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

class PrivateKeyCache extends _PrivateKeyTable {
  PrivateKeyCache() {
    _privateKeyCaches = CacheManager().getPool('private_id_key');
    _decryptKeysCache = CacheManager().getPool('private_msg_keys');
  }

  late final CachePool<ID, PrivateKey> _privateKeyCaches;
  late final CachePool<ID, List<DecryptKey>> _decryptKeysCache;

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    double now = Time.currentTimeSeconds;
    // 1. check memory cache
    CachePair<List<DecryptKey>>? pair = _decryptKeysCache.fetch(user, now: now);
    CacheHolder<List<DecryptKey>>? holder = pair?.holder;
    List<DecryptKey>? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
        _decryptKeysCache.updateValue(user, null, 128, now: now);
      } else {
        // FIXME: no lock, should not return empty values here
        if (holder.isAlive(now: now)) {
          // value not exists
          return [];
        }
        // cache expired, wait to reload
        holder.renewal(128, now: now);
      }
      // 2. load from database
      value = await super.getPrivateKeysForDecryption(user);
      // update cache
      _decryptKeysCache.updateValue(user, value, 36000, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    double now = Time.currentTimeSeconds;
    // 1. check memory cache
    CachePair<PrivateKey>? pair = _privateKeyCaches.fetch(user, now: now);
    CacheHolder<PrivateKey>? holder = pair?.holder;
    PrivateKey? value = pair?.value;
    if (value == null) {
      if (holder == null) {
        // not load yet, wait to load
        _privateKeyCaches.updateValue(user, null, 128, now: now);
      } else {
        // FIXME: no lock, should not return empty value here
        if (holder.isAlive(now: now)) {
          // value not exists
          return null;
        }
        // cache expired, wait to reload
        holder.renewal(128, now: now);
      }
      // 2. load from database
      value = await super.getPrivateKeyForVisaSignature(user);
      // update cache
      _privateKeyCaches.updateValue(user, value, 36000, now: now);
    }
    // OK, return cache now
    return value;
  }

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async {
    double now = Time.currentTimeSeconds;

    // 1. update memory cache
    if (type == PrivateKeyDBI.kMeta) {
      // update 'id_key'
      _privateKeyCaches.updateValue(user, key, 36000, now: now);
    } else {
      // add to old keys
      List<DecryptKey> decryptKeys = await getPrivateKeysForDecryption(user);
      List<PrivateKey> privateKeys = PrivateKeyDBI.convertPrivateKeys(decryptKeys);
      List<PrivateKey>? keys = PrivateKeyDBI.insertKey(key, privateKeys);
      if (keys == null) {
        // key already exists, nothing changed
        return false;
      }
      // update 'msg_keys'
      decryptKeys = PrivateKeyDBI.convertDecryptKeys(keys);
      _decryptKeysCache.updateValue(user, decryptKeys, 36000, now: now);
    }

    // 2. save to database
    if (await super.savePrivateKey(key, type, user, sign: sign, decrypt: decrypt)) {
      //
    } else {
      Log.error('failed to save private key: $user');
      return false;
    }

    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kPrivateKeySaved, this, {
      'user': user,
      'key': key,
    });
    return true;
  }

}


class MsgKeyCache implements CipherKeyDBI {
  MsgKeyCache();

  /// receiver => {sender => key}
  final Map<ID, Map<ID, SymmetricKey>> _caches = {};

  @override
  Future<void> cacheCipherKey(ID sender, ID receiver, SymmetricKey? key) async {
    if (receiver.isBroadcast) {
      // broadcast message has no key
      return;
    }
    Map<ID, SymmetricKey>? keyMap = _caches[receiver];
    if (key != null) {
      if (keyMap == null) {
        keyMap = {};
        _caches[receiver] = keyMap;
      }
      keyMap[sender] = key;
    } else if (keyMap == null || keyMap.remove(sender) == null) {
      Log.warning('cipher key not exists: $sender -> $receiver');
    } else {
      Log.debug("cipher key removed: $sender -> $receiver");
    }
  }

  @override
  Future<SymmetricKey?> getCipherKey(ID sender, ID receiver, {bool generate = false}) async {
    if (receiver.isBroadcast) {
      // broadcast message has no key
      return PlainKey.getInstance();
    }
    SymmetricKey? key;
    // check cache first
    Map<ID, SymmetricKey>? keyMap = _caches[receiver];
    if (keyMap != null) {
      key = keyMap[sender];
    }
    // if key not found, generate it
    if (key == null && generate) {
      if (keyMap == null) {
        keyMap = {};
        _caches[receiver] = keyMap;
      }
      // create new key
      key = SymmetricKey.generate(SymmetricKey.kAES);
      keyMap[sender] = key!;
      Log.warning('cipher key generated: $sender -> $receiver');
    }
    return key;
  }

}
