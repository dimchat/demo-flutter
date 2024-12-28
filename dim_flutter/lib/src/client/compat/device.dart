
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../common/platform.dart';
import '../../widgets/permissions.dart';

class DeviceInfo {
  factory DeviceInfo() => _instance;
  static final DeviceInfo _instance = DeviceInfo._internal();
  DeviceInfo._internal() {
    DeviceInfoPlugin info = DeviceInfoPlugin();
    if (DevicePlatform.isWeb) {
      info.webBrowserInfo.then(_loadWeb);
    } else if (DevicePlatform.isAndroid) {
      info.androidInfo.then(_loadAndroid);
    } else if (DevicePlatform.isIOS) {
      info.iosInfo.then(_loadIOS);
    } else if (DevicePlatform.isMacOS) {
      info.macOsInfo.then(_loadMacOS);
    } else if (DevicePlatform.isLinux) {
      info.linuxInfo.then(_loadLinux);
    } else if (DevicePlatform.isWindows) {
      info.windowsInfo.then(_loadWindows);
    } else {
      assert(false, 'unknown platform');
    }
    language = DevicePlatform.localeName;
    // fix for android
    fixPhotoPermissions();
  }

  void _loadWeb(WebBrowserInfo info) {
    // FIXME: all
    systemVersion = info.appVersion ?? '';
    systemModel = info.appCodeName ?? '';
    systemDevice = info.platform ?? '';
    deviceBrand = info.product ?? '';
    deviceBoard = info.productSub ?? '';
    deviceManufacturer = info.vendor ?? '';
  }
  void _loadAndroid(AndroidDeviceInfo info) {
    systemVersion = info.version.release;
    systemModel = info.model;
    systemDevice = info.device;
    deviceBrand = info.brand;
    deviceBoard = info.board;
    deviceManufacturer = info.manufacturer;
  }
  void _loadIOS(IosDeviceInfo info) {
    // FIXME: device, brand, board
    systemVersion = info.systemVersion;
    systemModel = info.model;
    systemDevice = info.utsname.machine;
    deviceBrand = "Apple";
    deviceBoard = info.utsname.machine;
    deviceManufacturer = "Apple Inc.";
  }
  void _loadMacOS(MacOsDeviceInfo info) {
    // FIXME: device, brand, board
    systemVersion = '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}';
    systemModel = info.model;
    systemDevice = info.systemGUID ?? info.osRelease;
    deviceBrand = "Apple";
    deviceBoard = info.systemGUID ?? info.osRelease;
    deviceManufacturer = "Apple Inc.";
  }
  void _loadLinux(LinuxDeviceInfo info) {
    // FIXME: model, device, brand, board, manufacturer
    systemVersion = info.version ?? info.versionId ?? info.versionCodename ?? '';
    systemModel = info.name;
    systemDevice = info.prettyName;
    deviceBrand = "Linux";
    deviceBoard = info.prettyName;
    deviceManufacturer = "Linux";
  }
  void _loadWindows(WindowsDeviceInfo info) {
    // FIXME: model, device, brand, board
    systemVersion = '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';
    systemModel = info.csdVersion;
    systemDevice = info.deviceId;
    deviceBrand = "Windows";
    deviceBoard = info.productName;
    deviceManufacturer = info.registeredOwner;
  }

  String language = "zh-CN";
  String systemVersion = "4.0";
  String systemModel = "HMS";
  String systemDevice = "hammerhead";
  String deviceBrand = "HUAWEI";
  String deviceBoard = "hammerhead";
  String deviceManufacturer = "HUAWEI";

}

class AppPackageInfo {
  factory AppPackageInfo() => _instance;
  static final AppPackageInfo _instance = AppPackageInfo._internal();
  AppPackageInfo._internal() {
    PackageInfo.fromPlatform().then(_load);
  }

  void _load(PackageInfo info) {
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
