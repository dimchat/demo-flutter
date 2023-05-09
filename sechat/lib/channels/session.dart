import 'package:dim_client/dim_client.dart';
import 'package:flutter/services.dart';

import '../client/client.dart';
import '../client/messenger.dart';
import '../client/session.dart';
import '../client/shared.dart';
import 'manager.dart';

class SessionChannel extends MethodChannel {
  SessionChannel(super.name) {
    setMethodCallHandler(_handle);
  }

  /// MethCallHandler
  Future<void> _handle(MethodCall call) async {
    String method = call.method;
    Map arguments = call.arguments;
    if (method == ChannelMethods.onStateChanged) {
      int previous = Converter.getInt(arguments['previous']) ?? 0;
      int current = Converter.getInt(arguments['current']) ?? 0;
      int now = Converter.getInt(arguments['now']) ?? 0;
      _onStateChanged(previous, current, now);
    } else if (method == ChannelMethods.onReceived) {
      Uint8List payload = arguments['payload'];
      String remote = arguments['remote'];
      _onReceived(payload, remote);
    }
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

  void _onReceived(Uint8List data, String remote) {
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
      Arrival ship = _ArrivalShip();
      for (Uint8List res in responses) {
        Log.debug('sending response: ${res.length} bytes to $address');
        messenger.session.sendResponse(res, ship, remote: address);
      }
    });
  }

  //
  //  Invoke Methods
  //
  Future<dynamic> _invoke(String method, Map? arguments) async {
    try {
      return await invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return;
    }
  }

  /// connect to remote address(host, port)
  Future<void> connect(String host, int port) async {
    _invoke(ChannelMethods.connect, {
      'host': host, 'port': port,
    });
  }

  /// login with user ID
  Future<bool> login(ID user) async {
    return await _invoke(ChannelMethods.login, {
      'user': user.toString(),
    });
  }

  /// set session key for login accepted
  Future<void> setSessionKey(String? session) async {
    return await _invoke(ChannelMethods.setSessionKey, {
      'session': session,
    });
  }

  /// get session state
  Future<int> getState() async {
    return await _invoke(ChannelMethods.getState, null);
  }

  /// send message with data pack & priority
  Future<void> sendMessagePackage(ReliableMessage rMsg, Uint8List data, int priority) async {
    return await _invoke(ChannelMethods.sendMessagePackage, {
      'msg': rMsg.toMap(),
      'data': data,
      'priority': priority,
    });
  }

  /// pack message payload to network package
  Future<Uint8List> packData(Uint8List payload) async {
    return await _invoke(ChannelMethods.packData, {
      'payload': payload,
    });
  }
  /// unpack payload from network package
  Future<Map> unpackData(Uint8List data) async {
    return await _invoke(ChannelMethods.unpackData, {
      'data': data,
    });
  }

}

class _ArrivalShip extends Arrival {
  // TODO: implement Arrival Ship

  @override
  Uint8List get payload => throw UnimplementedError();

}
