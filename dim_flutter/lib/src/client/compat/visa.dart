
import 'dart:typed_data';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../../common/platform.dart';
import '../../models/newest.dart';
import '../../ui/language.dart';
import '../shared.dart';


extension SysEnvExtension on Visa {

  Visa? clone() {
    // clone for modifying
    Map info = copyMap(false);
    Document? visa = Document.parse(info);
    if (visa is Visa) {
      assert(visa.publicKey != null, 'visa error: $visa');
      // update system environment
      visa.setProperty('app', _getAppInfo(visa));
      visa.setProperty('sys', _getDeviceInfo(visa));
      String? terminal = visa.getString('terminal');
      // reset visa terminal
      if (terminal == null || terminal.isEmpty) {
        visa['terminal'] = _getDeviceId();
      } else {
        Log.info('visa terminal: "$terminal"');
      }
      return visa;
    }
    assert(false, 'visa error: $info');
    return null;
  }

}

Map _getAppInfo(Visa visa) {
  var info = visa.getProperty('app');
  if (info == null) {
    info = {};
  } else if (info is Map) {
    // app info already exist, update it
  } else {
    assert(info is String, 'invalid app info: $info');
    info = {
      'app': info,
    };
  }
  var lang = LanguageDataSource();
  var newest = NewestManager();
  var shared = GlobalVariable();
  var client = shared.terminal;
  info['id'] = client.packageName;
  info['name'] = client.displayName;
  info['version'] = client.versionName;
  info['build'] = client.buildNumber;
  info['store'] = newest.store;
  info['language'] = lang.getCurrentLanguageCode();
  return info;
}

Map _getDeviceInfo(Visa visa) {
  var info = visa.getProperty('sys');
  if (info == null) {
    info = {};
  } else if (info is Map) {
    // device info already exist, update it
  } else {
    assert(info is String, 'invalid device info: $info');
    info = {
      'sys': info,
    };
  }
  GlobalVariable shared = GlobalVariable();
  var client = shared.terminal;
  info['locale'] = client.language; // DevicePlatform.localeName;
  info['model'] = client.systemModel;
  info['device'] = client.systemDevice;
  info['brand'] = client.deviceBrand;
  info['board'] = client.deviceBoard;
  info['manufacturer'] = client.deviceManufacturer;
  info['ver'] = client.systemVersion;
  info['os'] = DevicePlatform.operatingSystem;
  return info;
}

String _getDeviceId() {
  GlobalVariable shared = GlobalVariable();
  var client = shared.terminal;
  String device = client.systemDevice;
  Uint8List data = UTF8.encode(device);
  String terminal = Base58.encode(data);
  Log.info('device id: "$device" -> "$terminal" as visa terminal');
  return terminal;
}
