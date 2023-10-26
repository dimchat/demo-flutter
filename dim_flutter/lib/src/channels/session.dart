import 'package:flutter/services.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

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
    var arguments = call.arguments;
    if (method == ChannelMethods.onStateChanged) {
      // onStateChanged
      int previous = Converter.getInt(arguments['previous'], 0)!;
      int current = Converter.getInt(arguments['current'], 0)!;
      double now = Converter.getDouble(arguments['now'], 0)!;
      _onStateChanged(previous, current, now);
    } else if (method == ChannelMethods.onReceived) {
      // onReceived
      Uint8List payload = arguments['payload'];
      String remote = arguments['remote'];
      _onReceived(payload, remote);
    } else if (method == ChannelMethods.sendContent) {
      // sendContent
      Content? content = Content.parse(arguments['content']);
      ID? receiver = ID.parse(arguments['receiver']);
      if (content == null || receiver == null) {
        assert(false, 'failed to send content: $arguments');
      } else {
        _sendContent(content, receiver: receiver);
      }
    } else if (method == ChannelMethods.sendCommand) {
      // sendCommand
      Command? content = Command.parse(arguments['content']);
      ID? receiver = ID.parse(arguments['receiver']);
      if (content == null) {
        assert(false, 'failed to send command: $arguments');
      } else {
        _sendCommand(content, receiver: receiver);
      }
    }
  }

  void _onStateChanged(int previous, int current, double now) {
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
    SocketAddress? remoteAddress = SocketAddress.parse(remote);
    Log.warning("received data: ${data.length} bytes from $remote ($remoteAddress)");
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      assert(false, 'messenger not set');
      return;
    }
    messenger.processPackage(data).then((responses) {
      if (remoteAddress == null) {
        Log.error('remote socket error: $remote');
        return;
      }
      Arrival ship = _ArrivalShip();
      for (Uint8List res in responses) {
        Log.debug('sending response: ${res.length} bytes to $remoteAddress');
        messenger.session.sendResponse(res, ship, remote: remoteAddress);
      }
    });
  }

  void _sendCommand(Command content, {ID? sender, ID? receiver, int priority = 0}) {
    if (receiver == null) {
      // sending command to current station
      GlobalVariable shared = GlobalVariable();
      SharedMessenger? messenger = shared.messenger;
      receiver = messenger?.session.station.identifier;
      if (receiver == null) {
        assert(false, 'failed to get current station');
        return;
      }
    }
    _sendContent(content, sender: sender, receiver: receiver, priority: priority);
  }

  void _sendContent(Content content, {ID? sender, required ID receiver, int priority = 0}) {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    assert(messenger != null, 'messenger not set, not connect yet?');
    messenger?.sendContent(content, sender: sender, receiver: receiver, priority: priority);
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
  Future<void> connect(String host, int port) async =>
      await _invoke(ChannelMethods.connect, {
        'host': host, 'port': port,
      });

  /// login with user ID
  Future<bool> login(ID user) async =>
      await _invoke(ChannelMethods.login, {
        'user': user.toString(),
      });

  /// set session key for login accepted
  Future<void> setSessionKey(String? session) async =>
      await _invoke(ChannelMethods.setSessionKey, {
        'session': session,
      });

  /// get session state
  Future<int> getState() async =>
      await _invoke(ChannelMethods.getState, null);

  /// send message with data pack & priority
  Future<void> sendMessagePackage(ReliableMessage rMsg, Uint8List data, int priority) async =>
      await _invoke(ChannelMethods.sendMessagePackage, {
        'msg': rMsg.toMap(),
        'data': data,
        'priority': priority,
      });

  /// pack message payload to network package
  Future<Uint8List> packData(Uint8List payload) async =>
      await _invoke(ChannelMethods.packData, {
        'payload': payload,
      });

  /// unpack payload from network package
  Future<Map> unpackData(Uint8List data) async =>
      await _invoke(ChannelMethods.unpackData, {
        'data': data,
      });

}

class _ArrivalShip implements Arrival {
  // TODO: implement Arrival Ship

  @override
  Uint8List get payload => throw UnimplementedError();

}
