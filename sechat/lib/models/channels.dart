import 'package:dim_client/dim_client.dart';
import 'package:flutter/services.dart';

import '../client/client.dart';
import '../client/messenger.dart';
import '../client/session.dart';
import '../client/shared.dart';

class ChannelNames {

  static const String storage = "chat.dim/fileManager";

  static const String session = "chat.dim/session";
}

class ChannelMethods {

  //
  //  Storage channel
  //
  static const String cachesDirectory = "cachesDirectory";
  static const String temporaryDirectory = "temporaryDirectory";

  //
  //  Session channel
  //
  static const String connect = 'connect';
  static const String login = 'login';
  static const String setSessionKey = 'setSessionKey';
  static const String getState = 'getState';
  static const String sendMessagePackage = "queueMessagePackage";

  static const String onStateChanged = 'onStateChanged';
  static const String onReceived = 'onReceived';

}

class ChannelManager {
  factory ChannelManager() => _instance;
  static final ChannelManager _instance = ChannelManager._internal();
  ChannelManager._internal();

  //
  //  Channels
  //
  final StorageChannel storageChannel = StorageChannel(ChannelNames.storage);
  final SessionChannel sessionChannel = SessionChannel(ChannelNames.session);

}

class StorageChannel extends MethodChannel {
  StorageChannel(super.name);

  Future<String> get cachesDirectory async {
    try {
      return await invokeMethod(ChannelMethods.cachesDirectory);
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      rethrow;
    }
  }

  Future<String> get temporaryDirectory async {
    try {
      return await invokeMethod(ChannelMethods.temporaryDirectory);
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      rethrow;
    }
  }

}

class SessionChannel extends MethodChannel {
  SessionChannel(super.name) {
    setMethodCallHandler((call) async {
      String method = call.method;
      if (method == ChannelMethods.onStateChanged) {
        int previous = call.arguments['previous'];
        int current = call.arguments['current'];
        int now = call.arguments['now'];
        _onStateChanged(previous, current, now);
      } else if (method == ChannelMethods.onReceived) {
        String json = call.arguments['json'];
        String remote = call.arguments['remote'];
        _onReceived(json, remote);
      }
    });
  }

  void _onStateChanged(int previous, int current, int now) {
    Log.warning('onStateChanged: $previous -> $current');
    GlobalVariable shared = GlobalVariable();
    Client? client = shared.terminal;
    var session = client.session;
    if (session is SharedSession) {
      StateMachine fsm = session.fsm;
      fsm.currentState = SessionState(current);
      client.exitState(SessionState(previous), fsm, now);
    }
  }

  void _onReceived(String json, String remote) {
    Uint8List data = UTF8.encode(json);
    Log.warning("received data: ${data.length} bytes from $remote");
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      assert(false, 'messenger not set');
      return;
    }
    messenger.processPackage(data).then((responses) {
      remote = remote.replaceAll('/', '');
      List array = remote.split(':');
      SocketAddress address = SocketAddress(array[0], int.parse(array[1]));
      Arrival ship = ArrivalShip();
      for (Uint8List res in responses) {
        Log.debug('sending response: ${res.length} bytes to $address');
        messenger.session.sendResponse(res, ship, remote: address);
      }
    });
  }

  Future<void> connect(String host, int port) async {
    try {
      return await invokeMethod(ChannelMethods.connect, {
        'host': host, 'port': port,
      });
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return;
    }
  }

  Future<bool> login(ID user) async {
    try {
      return await invokeMethod(ChannelMethods.login, {
        'user': user.string,
      });
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return false;
    }
  }

  Future<void> setSessionKey(String? session) async {
    try {
      return await invokeMethod(ChannelMethods.setSessionKey, {
        'session': session,
      });
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return;
    }
  }

  Future<int> getState() async {
    try {
      return await invokeMethod(ChannelMethods.getState);
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return -1;
    }
  }

  Future<void> sendMessagePackage(ReliableMessage rMsg, Uint8List data, int priority) async {
    try {
      String b64 = Base64.encode(data);
      return await invokeMethod(ChannelMethods.sendMessagePackage, {
        'msg': rMsg.dictionary, 'data': b64, 'priority': priority,
      });
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return;
    }
  }

}

class ArrivalShip extends Arrival {
  // TODO: implement Arrival Ship

  @override
  Uint8List get payload => throw UnimplementedError();

}
