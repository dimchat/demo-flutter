import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../channels/session.dart';
import '../common/constants.dart';
import '../models/station.dart';
import '../network/neighbor.dart';
import 'messenger.dart';
import 'packer.dart';
import 'processor.dart';
import 'session.dart';
import 'shared.dart';


class Client extends Terminal {
  Client(super.facebook, super.sdb);

  SessionState? sessionState;

  int get sessionStateOrder =>
      sessionState?.index ?? SessionStateOrder.kDefault;

  String? get sessionStateText {
    int order = sessionStateOrder;
    switch (order) {
      case SessionStateOrder.kDefault:
        return 'Waiting'.tr;  // waiting to connect
      case SessionStateOrder.kConnecting:
        return 'Connecting'.tr;
      case SessionStateOrder.kConnected:
        return 'Connected'.tr;
      case SessionStateOrder.kHandshaking:
        return 'Handshaking'.tr;
      case SessionStateOrder.kRunning:
        return null;  // normal running
      default:
        reconnect();
        return 'Disconnected'.tr;  // error
    }
  }

  /// connect to the neighbor station
  Future<ClientMessenger?> reconnect() async {
    NeighborInfo? station = await getNeighborStation();
    if (station == null) {
      Log.error('failed to get neighbor station');
      return null;
    }
    Log.warning('connecting to station: $station');
    // return await connect('192.168.31.152', 9394);
    // return await connect('129.226.12.4', 9394);
    return await connect(station.host, station.port);
  }

  @override
  Future<ClientMessenger> connect(String host, int port) async {
    Log.warning('connecting to host: $host, port: $port');
    ClientMessenger messenger = await super.connect(host, port);
    // connect via session channel
    ChannelManager manager = ChannelManager();
    SessionChannel channel = manager.sessionChannel;
    await channel.connect(host, port).then((value) =>
        facebook.currentUser.then((user) {
          if (user != null) {
            login(user.identifier);
          }
        }));
    return messenger;
  }

  @override
  bool login(ID current) {
    ChannelManager manager = ChannelManager();
    SessionChannel channel = manager.sessionChannel;
    channel.login(current);
    return super.login(current);
  }

  @override
  ClientSession createSession(Station station) {
    ClientSession session = SharedSession(station, sdb);
    session.start();
    return session;
  }

  @override
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook) {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger messenger = SharedMessenger(session, facebook, shared.mdb);
    shared.messenger = messenger;
    return messenger;
  }

  @override
  Packer createPacker(CommonFacebook facebook, ClientMessenger messenger) {
    return SharedPacker(facebook, messenger);
  }

  @override
  Processor createProcessor(CommonFacebook facebook, ClientMessenger messenger) {
    return SharedProcessor(facebook, messenger);
  }

  Future<void> onAppLifecycleStateChanged(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await enterForeground();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        await enterBackground();
        break;
      default:
        break;
    }
  }

  //
  //  FSM Delegate
  //

  @override
  Future<void> exitState(SessionState previous, SessionStateMachine ctx, double now) async {
    await super.exitState(previous, ctx, now);
    sessionState = ctx.currentState;
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServerStateChanged, this, {
      'previous': previous,
      'current': sessionState,
    });
  }

  //
  //  DeviceMixin
  //

  final _DeviceInfo _deviceInfo = _DeviceInfo();
  final _PackageInfo _packageInfo = _PackageInfo();

  String get packageName => _packageInfo.packageName;

  @override
  String get displayName => _packageInfo.displayName;

  @override
  String get versionName => _packageInfo.versionName;

  String get buildNumber => _packageInfo.buildNumber;

  @override
  String get language => _deviceInfo.language;

  @override
  String get systemVersion => _deviceInfo.systemVersion;

  @override
  String get systemModel => _deviceInfo.systemModel;

  @override
  String get systemDevice => _deviceInfo.systemDevice;

  @override
  String get deviceBrand => _deviceInfo.deviceBrand;

  @override
  String get deviceBoard => _deviceInfo.deviceBoard;

  @override
  String get deviceManufacturer => _deviceInfo.deviceManufacturer;

}

class _DeviceInfo {
  factory _DeviceInfo() => _instance;
  static final _DeviceInfo _instance = _DeviceInfo._internal();
  _DeviceInfo._internal() {
    DeviceInfoPlugin info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      info.androidInfo.then(_loadAndroid);
    } else if (Platform.isIOS) {
      info.iosInfo.then(_loadIOS);
    } else if (Platform.isMacOS) {
      info.macOsInfo.then(_loadMacOS);
    } else if (Platform.isLinux) {
      info.linuxInfo.then(_loadLinux);
    } else if (Platform.isWindows) {
      info.windowsInfo.then(_loadWindows);
    } else {
      assert(false, 'unknown platform');
    }
    language = Platform.localeName;
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

class _PackageInfo {
  factory _PackageInfo() => _instance;
  static final _PackageInfo _instance = _PackageInfo._internal();
  _PackageInfo._internal() {
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
