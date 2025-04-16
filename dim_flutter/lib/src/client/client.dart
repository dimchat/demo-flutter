import 'dart:ui';

import 'package:get/get.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/client.dart';
import 'package:dim_client/ws.dart' show Runner;

import '../common/constants.dart';
import '../models/station.dart';
import '../network/neighbor.dart';
import 'compat/device.dart';

import 'messenger.dart';
import 'packer.dart';
import 'processor.dart';
import 'shared.dart';


class Client extends Terminal {
  Client(super.facebook, super.sdb);

  SessionState? get sessionState => session?.state;

  int get sessionStateOrder =>
      sessionState?.index ?? SessionStateOrder.init.index;

  String? get sessionStateText {
    int order = sessionStateOrder;
    if (order == SessionStateOrder.init.index) {
      return 'Waiting'.tr;  // waiting to connect
    } else if (order == SessionStateOrder.connecting.index) {
      return 'Connecting'.tr;
    } else if (order == SessionStateOrder.connected.index) {
      return 'Connected'.tr;
    } else if (order == SessionStateOrder.handshaking.index) {
      return 'Handshaking'.tr;
    } else if (order == SessionStateOrder.running.index) {
      return null;  // normal running
    } else {
      reconnect();
      return 'Disconnected'.tr;  // error
    }
  }

  /// connect to the neighbor station
  Future<ClientMessenger?> reconnect() async {
    NeighborInfo? station = await getNeighborStation();
    if (station == null) {
      logError('failed to get neighbor station');
      return null;
    }
    logWarning('connecting to station: $station');
    // return await connect('192.168.31.152', 9394);
    // return await connect('170.106.141.194', 9394);
    // return await connect('129.226.12.4', 9394);
    return await connect(station.host, station.port);
  }

  // @override
  // ClientSession createSession(Station station) {
  //   ClientSession session = ClientSession(sdb, station);
  //   session.start(this);
  //   return session;
  // }

  @override
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook) {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger messenger = SharedMessenger(session, facebook, shared.database);
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

  //
  //  App Lifecycle
  //

  Future<void> enterBackground() async {
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // not connect
      return;
    }
    logInfo("App Lifecycle: report offline before pause session");
    // check signed in user
    ClientSession cs = transceiver.session;
    ID? uid = cs.identifier;
    if (uid != null) {
      // already signed in, check session state
      SessionState? state = cs.state;
      if (state?.index == SessionStateOrder.running.index) {
        // report client state
        await transceiver.reportOffline(uid);
        // sleep a while for waiting 'report' command sent
        await Runner.sleep(const Duration(milliseconds: 512));
      }
    }
    // pause the session
    await cs.pause();
  }
  Future<void> enterForeground() async {
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // not connect
      return;
    }
    logInfo("App Lifecycle: report online after resume session");
    ClientSession cs = transceiver.session;
    // resume the session
    await cs.resume();
    // check signed in user
    ID? uid = cs.identifier;
    if (uid != null) {
      // already signed in, wait a while to check session state
      await Runner.sleep(const Duration(milliseconds: 512));
      SessionState? state = cs.state;
      if (state?.index == SessionStateOrder.running.index) {
        // report client state
        await transceiver.reportOnline(uid);
      }
    }
  }

  Future<void> onAppLifecycleStateChanged(AppLifecycleState state) async {
    GlobalVariable shared = GlobalVariable();
    switch (state) {
      case AppLifecycleState.resumed:
        logWarning('AppLifecycleState::enterForeground $state bg=${shared.isBackground}');
        if (shared.isBackground != false) {
          shared.isBackground = false;
          await enterForeground();
        }
        break;
      // case AppLifecycleState.inactive:
      //   break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        logWarning('AppLifecycleState::enterBackground $state bg=${shared.isBackground}');
        if (shared.isBackground != true) {
          shared.isBackground = true;
          await enterBackground();
        }
        break;
      default:
        logInfo("AppLifecycleState::unknown state=$state bg=${shared.isBackground}");
        break;
    }
  }

  //
  //  Send message
  //

  final List<Triplet<ID, Content, int>> _outgoing = [];

  void addWaitingContent(Content content, {required ID receiver, int priority = 0}) =>
      _outgoing.add(Triplet(receiver, content, priority));

  Future<int> _sendWaitingContents(ID uid, ClientMessenger messenger) async {
    ID receiver;
    Content content;
    int prior;
    Triplet<ID, Content, int> triplet;
    Pair<InstantMessage, ReliableMessage?> res;
    int success = 0;
    while (_outgoing.isNotEmpty) {
      triplet = _outgoing.removeAt(0);
      receiver = triplet.first;
      content = triplet.second;
      prior = triplet.third;
      logInfo('[safe channel] send content: $receiver, $content');
      res = await messenger.sendContent(content, sender: uid, receiver: receiver, priority: prior);
      if (res.second != null) {
        success += 1;
      }
    }
    return success;
  }

  @override
  Future<bool> process() async {
    if (_outgoing.isEmpty) {
      return await super.process();
    }
    // check session state
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // not connect
      return false;
    }
    ClientSession session = transceiver.session;
    ID? uid = session.identifier;
    SessionState? state = session.state;
    if (uid == null || state?.index != SessionStateOrder.running.index) {
      // handshake not accepted
      return false;
    }
    int success = await _sendWaitingContents(uid, transceiver);
    return success > 0;
  }

  //
  //  FSM Delegate
  //

  @override
  Future<void> exitState(SessionState? previous, SessionStateMachine ctx, DateTime now) async {
    await super.exitState(previous, ctx, now);
    SessionState? current = ctx.currentState;
    logInfo('server state changed: $previous => $current');
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServerStateChanged, this, {
      'previous': previous,
      'current': current,
    });
  }

  //
  //  DeviceMixin
  //

  final DeviceInfo _deviceInfo = DeviceInfo();
  final AppPackageInfo _packageInfo = AppPackageInfo();

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
