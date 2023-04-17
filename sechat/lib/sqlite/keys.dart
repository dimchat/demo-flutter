import 'helper/sqlite.dart';


///
///  Store private keys, message keys
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
        // msg key
        DatabaseConnector.createTable(db, tMsgKey, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "sender VARCHAR(64) NOT NULL",
          "receiver VARCHAR(64) NOT NULL",
          "pwd TEXT NOT NULL",
        ]);
        DatabaseConnector.createIndex(db, tMsgKey,
            name: 'direction_index', fields: ['sender', 'receiver']);
      });

  static const String dbName = 'key.db';
  static const int dbVersion = 1;

  static const String tPrivateKey = 't_private_key';
  static const String tMsgKey     = 't_msg_key';

}


PrivateKey _extractPrivateKey(ResultSet resultSet, int index) {
  String? json = resultSet.getString('pri_key');
  Map? info = JSON.decode(json!);
  return PrivateKey.parse(info)!;
}

class PrivateKeyTable extends DataTableHandler<PrivateKey> implements PrivateKeyDBI {
  PrivateKeyTable() : super(CryptoKeyDatabase(), _extractPrivateKey);

  static const String _table = CryptoKeyDatabase.tPrivateKey;
  static const List<String> _selectColumns = ["pri_key"];
  static const List<String> _insertColumns = ["uid", "pri_key", "type", "sign", "decrypt"];

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.string);
    cond.addCondition(SQLConditions.kAnd, left: 'decrypt', comparison: '<>', right: 0);
    // WHERE uid='$user' AND decrypt=1 ORDER BY type DESC LIMIT 3
    List<PrivateKey> keys = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'type DESC', limit: 3);
    return PrivateKeyDBI.convertDecryptKeys(keys);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async {
    // TODO: support multi private keys
    return await getPrivateKeyForVisaSignature(user);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.string);
    cond.addCondition(SQLConditions.kAnd, left: 'type', comparison: '=', right: PrivateKeyDBI.kMeta);
    cond.addCondition(SQLConditions.kAnd, left: 'sign', comparison: '<>', right: 0);
    // WHERE uid='$user' AND type='M' AND decrypt=1 ORDER BY id DESC  LIMIT 1
    List<PrivateKey> keys = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // return first record only
    return keys.isEmpty ? null : keys[0];
  }

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async {
    String json = JSON.encode(key.dictionary);
    List values = [user.string, json, type, sign, decrypt];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}


SymmetricKey _extractPassword(ResultSet resultSet, int index) {
  String? json = resultSet.getString('pwd');
  Map? info = JSON.decode(json!);
  return SymmetricKey.parse(info)!;
}

class MsgKeyTable extends DataTableHandler<SymmetricKey> implements CipherKeyDBI {
  MsgKeyTable() : super(CryptoKeyDatabase(), _extractPassword);

  static const String _table = CryptoKeyDatabase.tMsgKey;
  static const List<String> _selectColumns = ["pwd"];
  static const List<String> _insertColumns = ["sender", "receiver", "pwd"];

  @override
  Future<void> cacheCipherKey(ID sender, ID receiver, SymmetricKey? key) async {
    if (receiver.isBroadcast) {
      // broadcast message has no key
      return;
    }
    if (key != null && await getCipherKey(sender, receiver) == null) {
      // insert new key for (sender => receiver)
      String json = JSON.encode(key.dictionary);
      List values = [sender.string, receiver.string, json];
      await insert(_table, columns: _insertColumns, values: values);
      return;
    }
    // build condition
    SQLConditions cond;
    cond = SQLConditions(left: 'sender', comparison: '=', right: sender.string);
    cond.addCondition(SQLConditions.kAnd,
        left: 'receiver', comparison: '=', right: receiver.string);
    if (key == null) {
      // remove old key for (sender => receiver)
      await delete(_table, conditions: cond);
    } else {
      // update key for (sender => receiver)
      String json = JSON.encode(key.dictionary);
      await update(_table, values: {'pwd': json}, conditions: cond);
    }
  }

  @override
  Future<SymmetricKey?> getCipherKey(ID sender, ID receiver, {bool generate = false}) async {
    if (receiver.isBroadcast) {
      // broadcast message has no key
      return PlainKey.getInstance();
    }
    SQLConditions cond;
    cond = SQLConditions(left: 'sender', comparison: '=', right: sender.string);
    cond.addCondition(SQLConditions.kAnd,
        left: 'receiver', comparison: '=', right: receiver.string);
    List<SymmetricKey> keys = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);
    // return first record only
    if (keys.isNotEmpty) {
      return keys[0];
    } else if (generate) {
      return SymmetricKey.generate(SymmetricKey.kAES);
    } else {
      return null;
    }
  }

}
