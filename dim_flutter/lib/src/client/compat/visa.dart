
import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';

import '../../common/platform.dart';
import '../../ui/language.dart';
import '../shared.dart';


extension SysEnvExtension on Visa {

  Visa? clone() {
    // clone for modifying
    Map info = copyMap(false);
    Document? visa = Document.parse(info);
    if (visa is Visa) {} else {
      assert(false, 'visa error: $info');
      return null;
    }
    assert(visa.publicKey != null, 'visa error: $visa');
    // update system environment
    visa.setProperty('app', _getAppInfo(visa));
    visa.setProperty('sys', _getDeviceInfo(visa));
    // reset visa terminal
    var terminal = visa['terminal'];
    visa['terminal'] = SysEnv().terminal;
    Log.info('update visa terminal: "$terminal" => "${SysEnv().terminal}"');
    return visa;
  }

}

Map _getAppInfo(Visa visa) {
  var info = visa.getProperty('app');
  if (info == null) {
    info = <String, dynamic>{};
  } else if (info is Map) {
    // app info already exist, update it
  } else {
    assert(info is String, 'invalid app info: $info');
    info = <String, dynamic>{
      'app': info,
    };
  }
  var lang = LanguageDataSource();
  var sys = SysEnv();
  var shared = GlobalVariable();
  var client = shared.terminal;
  info['id'] = client.packageName;
  info['name'] = client.displayName;
  info['version'] = client.versionName;
  info['build'] = client.buildNumber;
  info['store'] = sys.storeName;
  info['language'] = lang.getCurrentLanguageCode();
  return info;
}

Map _getDeviceInfo(Visa visa) {
  var info = visa.getProperty('sys');
  if (info == null) {
    info = <String, dynamic>{};
  } else if (info is Map) {
    // device info already exist, update it
  } else {
    assert(info is String, 'invalid device info: $info');
    info = <String, dynamic>{
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
