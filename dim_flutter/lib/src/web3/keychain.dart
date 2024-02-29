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

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';


// https://iancoleman.io/bip39/#english

class Keychain {
  Keychain(this.database);

  final PrivateKeyDBI database;

  ID get master => ID.parse('may@anywhere')!;

  ///
  ///   Mnemonic
  ///

  String generate({int strength = 128}) => generateMnemonic(strength: strength);

  Future<String?> get mnemonic async {
    PrivateKey? puppet = await database.getPrivateKeyForVisaSignature(master);
    String? pem = puppet?.getString('data', null);
    Log.debug('master key data: $pem, $master');
    if (pem == null) {
      return null;
    }
    // unwrap key data
    List<String> rows = pem.split(RegExp(r'\r\n?|\n'));
    String entropy = rows
        .skipWhile((row) => row.startsWith('-----BEGIN'))
        .takeWhile((row) => !row.startsWith('-----END'))
        .map((row) => row.trim())
        .join('');
    Log.debug('get entropy: $entropy, $master');
    assert(entropy.length == 32, 'entropy length error: [$entropy]');
    return entropyToMnemonic(entropy);
  }

  Future<bool> saveMnemonic(String words) async {
    String entropy;
    try {
      entropy = mnemonicToEntropy(words);
    } on ArgumentError {
      // mnemonic error
      return false;
    } on StateError {
      // entropy error
      return false;
    }
    PrivateKey puppet = PrivateKey.parse({
      'algorithm': AsymmetricKey.kECC,
      'data': entropy,
    })!;
    Log.debug('save mnemonic: $words => $entropy');
    return await database.savePrivateKey(puppet, PrivateKeyDBI.kMeta, master,
        sign: 1, decrypt: 0);
  }

  ///
  ///   Wallets
  ///

  Future<BIP32?> get btcWallet async => await getWallet("m/44'/0'/0'/0/0");
  Future<BIP32?> get ethWallet async => await getWallet("m/44'/60'/0'/0/0");

  Future<BIP32?> getWallet(String path) async {
    String? words = await mnemonic;
    if (words == null) {
      Log.warning('mnemonic not found');
      return null;
    }
    Uint8List seed = mnemonicToSeed(words);
    BIP32 wallet = BIP32.fromSeed(seed).derivePath(path);
    assert(wallet.privateKey != null, 'failed to derive private key: $words');
    Log.debug('get wallet: $path, $words');
    return wallet;
  }

  ///
  ///   Private Key
  ///

  Future<PrivateKey?> get btcKey async => getPrivateKey(await btcWallet);
  Future<PrivateKey?> get ethKey async => getPrivateKey(await ethWallet);

  static PrivateKey? getPrivateKey(BIP32? wallet) {
    Uint8List? privateKey = wallet?.privateKey;
    if (privateKey == null) {
      return null;
    }
    return PrivateKey.parse({
      'algorithm': AsymmetricKey.kECC,
      'data': Hex.encode(privateKey),
    });
  }

  ///
  ///   Wallet Address
  ///

  Future<String?> get btcAddress async {
    PrivateKey? privateKey = await btcKey;
    PublicKey? publicKey = privateKey?.publicKey;
    if (publicKey == null) {
      return null;
    }
    Uint8List data = publicKey.data;
    const int network = 0x00;  // kBTCMain
    return BTCAddress.generate(data, network).toString();
  }

  Future<String?> get ethAddress async {
    PrivateKey? privateKey = await ethKey;
    PublicKey? publicKey = privateKey?.publicKey;
    if (publicKey == null) {
      return null;
    }
    Uint8List data = publicKey.data;
    return ETHAddress.generate(data).toString();
  }

}
