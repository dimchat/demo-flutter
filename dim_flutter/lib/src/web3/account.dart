/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import 'keychain.dart';


class Account {
  Account(this.database);

  final AccountDBI database;

  static int type = MetaType.kETH;

  ///  Create user account
  ///
  /// @param nickname  - user name
  /// @param avatarUrl - photo URL
  /// @return user ID
  Future<ID?> createUser({required String name, String? avatar}) async {
    // 1. generate mnemonic from keychain
    Keychain keychain = Keychain(database);
    String mnemonic = keychain.generate();
    bool ok = await keychain.saveMnemonic(mnemonic);
    assert(ok, 'failed to save mnemonic: $mnemonic');
    // 2. generate private key from mnemonic
    PrivateKey? idKey;
    int network = type;
    if (network == MetaType.kETH || network == MetaType.kExETH) {
      idKey = await keychain.ethKey;
    } else {
      assert(network == MetaType.kBTC || network == MetaType.kExBTC
          || network == MetaType.kMKM, 'meta type error: $network');
      idKey = await keychain.btcKey;
    }
    Log.debug('get private key: $idKey, mnemonic: $mnemonic');
    if (idKey == null) {
      assert(false, 'failed to get private key');
      return null;
    }
    // 3. generate user with name & avatar
    return await generateUser(name: name, avatar: avatar, idKey: idKey);
  }

  Future<ID> generateUser({required String name, String? avatar, required PrivateKey idKey}) async {
    //
    //  Step 1: generate meta with private key & meta type
    //
    Meta meta = Meta.generate(type, idKey);
    //
    //  Step 2: generate user ID with meta & address type
    //
    ID identifier = ID.generate(meta, EntityType.kUser);
    //
    //  Step 3: generate private key (RSA) for communication
    //
    PrivateKey msgKey = PrivateKey.generate(AsymmetricKey.kRSA)!;
    //
    //  Step 4: generate visa with ID and sign with private key
    //
    Visa visa = BaseVisa.from(identifier);
    visa.name = name;
    visa.avatar = PortableNetworkFile.parse(avatar);
    visa.publicKey = msgKey.publicKey as EncryptKey;
    Uint8List? sig = visa.sign(idKey);
    assert(sig != null, 'failed to sign visa: $identifier');
    //
    //  Step 5: save private key, meta & visa in local storage
    //          don't forget to upload them onto the DIM station
    //
    await database.saveMeta(meta, identifier);
    await database.savePrivateKey(idKey, PrivateKeyDBI.kMeta, identifier, decrypt: 0);
    await database.savePrivateKey(msgKey, PrivateKeyDBI.kVisa, identifier, decrypt: 1);
    await database.saveDocument(visa);
    // OK
    return identifier;
  }

}
