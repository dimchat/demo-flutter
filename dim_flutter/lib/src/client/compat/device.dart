
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:dim_client/ok.dart';

import '../../common/platform.dart';
import '../../widgets/permissions.dart';
import 'browser.dart';

class DeviceInfo with Logging {
  factory DeviceInfo() => _instance;
  static final DeviceInfo _instance = DeviceInfo._internal();
  DeviceInfo._internal() {
    /*await */loadDeviceInfo();
  }

  bool _loaded = false;

  Future<bool> loadDeviceInfo() async {
    if (_loaded) {
      return false;
    }
    try {
      await _loadInfo();
      logInfo('load device info, done!');
    } catch (e) {
      logError('failed to load device info: $e');
    } finally {
      _loaded = true;
    }
    return true;
  }

  Future<void> _loadInfo() async {
    DeviceInfoPlugin info = DeviceInfoPlugin();
    if (DevicePlatform.isWeb) {
      _loadWeb(await info.webBrowserInfo);
    } else if (DevicePlatform.isAndroid) {
      _loadAndroid(await info.androidInfo);
    } else if (DevicePlatform.isIOS) {
      _loadIOS(await info.iosInfo);
    } else if (DevicePlatform.isMacOS) {
      _loadMacOS(await info.macOsInfo);
    } else if (DevicePlatform.isLinux) {
      _loadLinux(await info.linuxInfo);
    } else if (DevicePlatform.isWindows) {
      _loadWindows(await info.windowsInfo);
    } else {
      assert(false, 'unknown platform');
    }
    language = DevicePlatform.localeName;
    // fix for android
    await fixPhotoPermissions();
  }

  void _loadWeb(WebBrowserInfo info) {
    // FIXME: all
    systemVersion = info.browserVersion ?? '';
    // systemModel = info.appCodeName ?? '';
    systemModel = info.browserName.name;     // chrome / safari / firefox / edge
    systemDevice = info.platform ?? '';      // MacIntel / Win32 / Android / iPhone
    deviceBrand = info.product ?? '';        // Gecko / AppleWebKit
    deviceBoard = '';
    deviceManufacturer = info.vendor ?? '';  // Google / Apple / Mozilla
  }
  void _loadAndroid(AndroidDeviceInfo info) {
    systemVersion = info.version.release;
    systemModel = info.model;                // "LIO-AL00"
    systemDevice = info.device;              // "HWLIO"
    deviceBrand = info.brand;                // "HUAWEI"
    deviceBoard = info.board;                // "LIO"
    deviceManufacturer = info.manufacturer;  // "HUAWEI"
  }
  void _loadIOS(IosDeviceInfo info) {
    // FIXME: device, brand, board
    systemVersion = info.systemVersion;
    systemModel = info.model;                // "iPhone"
    systemDevice = info.utsname.machine;     // "iPhone13,4"
    deviceBrand = "Apple";
    deviceBoard = '';
    deviceManufacturer = "Apple Inc.";
  }
  void _loadMacOS(MacOsDeviceInfo info) {
    // FIXME: device, brand, board
    systemVersion = '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}';
    systemModel = info.model;                // "iMacPro1,1"
    systemDevice = info.model;               // "iMacPro1,1"
    deviceBrand = "Apple";
    deviceBoard = '';
    deviceManufacturer = "Apple Inc.";
  }
  void _loadLinux(LinuxDeviceInfo info) {
    // FIXME: model, device, brand, board, manufacturer
    systemVersion = info.versionId ?? info.version ?? info.versionCodename ?? '';
    systemModel = info.prettyName;           // "Ubuntu 24.04 LTS"
    systemDevice = info.id;                  // "ubuntu"
    deviceBrand = info.id;                   // "ubuntu";
    deviceBoard = '';
    deviceManufacturer = info.name;          // "Canonical Ltd.";
  }
  void _loadWindows(WindowsDeviceInfo info) {
    // FIXME: model, device, brand, board
    systemVersion = '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';
    systemModel = info.productName;          // "Windows 11 Pro"
    systemDevice = info.deviceId;
    deviceBrand = "Microsoft Windows";
    deviceBoard = '';
    deviceManufacturer = 'Microsoft Corporation';
  }

  String language = "zh-CN";
  String systemVersion = "4.0";
  String systemModel = "HMS";
  String systemDevice = "hammerhead";
  String deviceBrand = "HUAWEI";
  String deviceBoard = "hammerhead";
  String deviceManufacturer = "HUAWEI";

}

class AppPackageInfo with Logging {
  factory AppPackageInfo() => _instance;
  static final AppPackageInfo _instance = AppPackageInfo._internal();
  AppPackageInfo._internal() {
    /*await */loadPackageInfo();
  }

  bool _loaded = false;

  Future<bool> loadPackageInfo() async {
    if (_loaded) {
      return false;
    }
    try {
      _loadInfo(await PackageInfo.fromPlatform());
      logInfo('load app package info, done!');
    } catch (e) {
      logError('failed to load app package info: $e');
    } finally {
      _loaded = true;
    }
    return true;
  }

  void _loadInfo(PackageInfo info) {
    packageName = info.packageName;
    displayName = info.appName;
    versionName = info.version;
    buildNumber = info.buildNumber;
  }

  String packageName = "chat.dim.tarsier";

  String displayName = "DIM";

  String versionName = "1.0.0";

  String buildNumber = "10001";

}
