
import 'package:flutter/services.dart';

import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../../ui/nav.dart';
import 'device.dart';


class SysInfo with Logging {
  factory SysInfo() => _instance;
  static final SysInfo _instance = SysInfo._internal();
  SysInfo._internal();

  final DeviceInfo deviceInfo = DeviceInfo();
  final AppPackageInfo packageInfo = AppPackageInfo();

  Future<bool> beforeLaunchApp() async {
    // Check Brightness & Language
    await initFacade();
    // Load settings
    var sys = SysEnv();
    sys.setAssetLoader(_AssetLoader());
    var text = await sys.loadString(sys.SETTINGS);
    logInfo('load settings: $text');
    // Load device + package info
    bool ok1 = await deviceInfo.loadDeviceInfo();
    bool ok2 = await packageInfo.loadPackageInfo();
    logInfo('load device info: $ok1');
    logInfo('load app package info: $ok2');
    if (ok1) {
      // Update terminal (device)
      String device = deviceInfo.systemDevice;
      String terminal = _normalizeDeviceName(device);
      if (terminal.isNotEmpty) {
        sys.terminal = terminal;
      }
      logInfo('device id: "$device" -> "$terminal" as visa terminal');
    }
    return ok1 && ok2;
  }

}

String _normalizeDeviceName(String device) => _trimTerminal(
    device.replaceAll(_terminalPattern, '_')
);

final _terminalPattern = RegExp(r'[^A-Za-z0-9\-.]+');

String _trimTerminal(String device, [String sep = '_']) {
  int start = 0;
  int end = device.length - 1;
  while (start < end && device[start] == sep) {
    ++start;
  }
  while (start < end && device[end] == sep) {
    --end;
  }
  if (start > end) {
    assert(false, 'terminal error: "$device"');
    return device;
  }
  return device.substring(start, end + 1);
}


class _AssetLoader implements AssetLoader {

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return await rootBundle.loadString(key, cache: cache);
  }

}


extension SyncMessageExtension on Message {

  String? get syncTerminal {
    String? fromWhere = getString('from');
    if (fromWhere == null) {
      return null;
    }
    int pos = fromWhere.indexOf('/');
    if (pos < 0) {
      return null;
    }
    String terminal = fromWhere.substring(pos + 1);
    if (terminal == SysEnv().terminal) {
      return null;
    }
    return terminal;
  }

}
