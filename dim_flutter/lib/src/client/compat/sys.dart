
import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';

import '../../ui/nav.dart';
import 'device.dart';


class SysEnv with Logging {
  factory SysEnv() => _instance;
  static final SysEnv _instance = SysEnv._internal();
  SysEnv._internal();

  final DeviceInfo deviceInfo = DeviceInfo();
  final AppPackageInfo packageInfo = AppPackageInfo();

  Future<bool> beforeLaunchApp() async {
    // Check Brightness & Language
    await initFacade();
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
        Register.terminal = terminal;
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
