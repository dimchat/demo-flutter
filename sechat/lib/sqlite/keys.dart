import '../client/dbi/account.dart';
import '../client/dbi/message.dart';
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
          "uid VARCHAR(64)",
          "pri_key TEXT",
          "type CHAR(1)",
          "sign BIT",
          "decrypt BIT",
        ]);
        // msg key
        DatabaseConnector.createTable(db, tMsgKey, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "sender VARCHAR(64)",
          "receiver VARCHAR(64)",
          "pwd TEXT",
        ]);
        DatabaseConnector.createIndex(db, tMsgKey,
            name: 'direction_index', fields: ['sender', 'receiver']);
      });

  static const String dbName = 'key.db';
  static const int dbVersion = 1;

  static const String tPrivateKey = 't_private_key';
  static const String tMsgKey     = 't_msg_key';

}


class _PrivateKeyExtractor implements DataRowExtractor<PrivateKey> {

  @override
  PrivateKey extractRow(ResultSet resultSet, int index) {
    String json = resultSet.getString('pri_key');
    Map? info = JSON.decode(json);
    return PrivateKey.parse(info)!;
  }

}

class PrivateKeyDB extends DataTableHandler<PrivateKey> implements PrivateKeyTable {
  PrivateKeyDB() : super(CryptoKeyDatabase());

  static const String _table = CryptoKeyDatabase.tPrivateKey;
  static const List<String> _selectColumns = ["pri_key"];
  static const List<String> _insertColumns = ["uid", "pri_key", "type", "sign", "decrypt"];

  @override
  DataRowExtractor<PrivateKey> get extractor => _PrivateKeyExtractor();

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.string);
    cond.addCondition(SQLConditions.and, left: 'decrypt', comparison: '!=', right: '0');
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
    cond.addCondition(SQLConditions.and, left: 'type', comparison: '=', right: PrivateKeyDBI.kMeta);
    cond.addCondition(SQLConditions.and, left: 'sign', comparison: '!=', right: '0');
    // WHERE uid='$user' AND type='M' AND decrypt=1 ORDER BY id DESC  LIMIT 1
    List<PrivateKey> keys = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // return first record only
    return keys.isEmpty ? null : keys[0];
  }

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user) async {
    if (key is DecryptKey) {
      return await storePrivateKey(key, type, user, sign: 1, decrypt: 1);
    } else {
      return await storePrivateKey(key, type, user, sign: 1, decrypt: 0);
    }
  }

  @override
  Future<bool> storePrivateKey(PrivateKey key, String type, ID user,
      {required int sign, required int decrypt}) async {
    String json = JSON.encode(key.dictionary);
    List values = [user.string, json, type, sign, decrypt];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}


class _MsgKeyExtractor implements DataRowExtractor<SymmetricKey> {

  @override
  SymmetricKey extractRow(ResultSet resultSet, int index) {
    String json = resultSet.getString('pwd');
    Map? info = JSON.decode(json);
    return SymmetricKey.parse(info)!;
  }

}

class MsgKeyDB extends DataTableHandler<SymmetricKey> implements MsgKeyTable {
  MsgKeyDB() : super(CryptoKeyDatabase());

  static const String _table = CryptoKeyDatabase.tMsgKey;
  static const List<String> _selectColumns = ["pwd"];
  static const List<String> _insertColumns = ["sender", "receiver", "pwd"];

  @override
  DataRowExtractor<SymmetricKey> get extractor => _MsgKeyExtractor();

  @override
  Future<void> cacheCipherKey(ID sender, ID receiver, SymmetricKey? key) async {
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
    cond.addCondition(SQLConditions.and,
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
    SQLConditions cond;
    cond = SQLConditions(left: 'sender', comparison: '=', right: sender.string);
    cond.addCondition(SQLConditions.and,
        left: 'receiver', comparison: '=', right: receiver.string);
    List<SymmetricKey> keys = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);
    // return first record only
    return keys.isEmpty ? null : keys[0];
  }

}
