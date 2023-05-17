import 'package:flutter/services.dart';
import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import 'manager.dart';

/// Keychain for iOS, macOS
class KeychainChannel extends MethodChannel implements PrivateKeyDBI {
  KeychainChannel(super.name);

  //
  //  Invoke Methods
  //
  Future<dynamic> _invoke(String method, dynamic arguments) async {
    try {
      return await invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return;
    }
  }

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async {
    int? res = await _invoke(ChannelMethods.savePrivateKey, {
      'user': user.toString(),
      'type': type,
      'key': key.toMap(),
    });
    return res == 1;
  }

  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async {
    Map? key = await _invoke(ChannelMethods.privateKeyForSignature, {
      'user': user.toString(),
    });
    return PrivateKey.parse(key);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    Map? key = await _invoke(ChannelMethods.privateKeyForVisaSignature, {
      'user': user.toString(),
    });
    return PrivateKey.parse(key);
  }

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    List? keys = await _invoke(ChannelMethods.privateKeysForDecryption, {
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
