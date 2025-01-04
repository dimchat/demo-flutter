import 'dart:typed_data';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/dim_flutter_platform_interface.dart';
import 'package:dim_flutter/dim_flutter_method_channel.dart';

class MockDimFlutterPlatform
    with MockPlatformInterfaceMixin
    implements DimFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

Pair<Address?, String?> generateAddress() {
  String words = generateMnemonic();
  Uint8List seed = mnemonicToSeed(words);
  BIP32 wallet = BIP32.fromSeed(seed).derivePath("m/44'/60'/0'/0/0");
  PrivateKey? privateKey = Keychain.getPrivateKey(wallet);
  PublicKey? publicKey = privateKey?.publicKey;
  if (publicKey == null) {
    return const Pair(null, null);
  }
  Uint8List data = publicKey.data;
  Address address = ETHAddress.generate(data);
  return Pair(address, words);
}
void batch(int count) {
  Pair<Address?, String?> result;
  Address? address;
  String? mnemonic;
  for (int i = 0; i < count; i++) {
    result = generateAddress();
    address = result.first;
    mnemonic = result.second;
    if (address == null) {
      //
    } else if (isGood(address.toString())) {
      Log.info('[$i] $address, mnemonic: $mnemonic');
    } else if (i % 50 == 0) {
      Log.debug('[$i] $address, mnemonic: $mnemonic');
    }
  }
}
bool isGood(String address) {
  for (String item in _array) {
    if (address.startsWith('0x$item') || address.endsWith(item)) {
      return true;
    }
  }
  return false;
}
List<String> _array = [
  '0000', '1111', '2222', '3333', '4444',
  '5555', '6666', '7777', '8888', '9999',
  '9527',
];

void main() {
  final DimFlutterPlatform initialPlatform = DimFlutterPlatform.instance;

  test('$MethodChannelDimFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDimFlutter>());
  });

  test('getPlatformVersion', () async {
    DimFlutter dimFlutterPlugin = DimFlutter();
    MockDimFlutterPlatform fakePlatform = MockDimFlutterPlatform();
    DimFlutterPlatform.instance = fakePlatform;

    expect(await dimFlutterPlugin.getPlatformVersion(), '42');

    Log.level = Log.kDebug;

    var loader = CompatLoader();
    loader.run();

    batch(10000);
  });
}
