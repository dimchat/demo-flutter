
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import 'manager.dart';

/// Keychain for iOS, macOS
class KeychainChannel extends SafeChannel implements PrivateKeyDBI {
  KeychainChannel(super.name);

  //
  //  Invoke Methods
  //

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async {
    int? res = await invoke(ChannelMethods.savePrivateKey, {
      'user': user.toString(),
      'type': type,
      'key': key.toMap(),
    });
    return res == 1;
  }

  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async {
    Map? key = await invoke(ChannelMethods.privateKeyForSignature, {
      'user': user.toString(),
    });
    return PrivateKey.parse(key);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    Map? key = await invoke(ChannelMethods.privateKeyForVisaSignature, {
      'user': user.toString(),
    });
    return PrivateKey.parse(key);
  }

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    List? keys = await invoke(ChannelMethods.privateKeysForDecryption, {
      'user': user.toString(),
    });
    if (keys == null || keys.isEmpty) {
      return [];
    }
    List<PrivateKey> privateKeys = [];
    PrivateKey? sk;
    for (var item in keys) {
      sk = PrivateKey.parse(item);
      if (sk == null) {
        assert(false, 'private key error: $item');
        continue;
      }
      privateKeys.add(sk);
    }
    return PrivateKeyDBI.convertDecryptKeys(privateKeys);
  }

}
