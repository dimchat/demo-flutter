import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';

import '../channels/manager.dart';

String titleWithState(String title, int state) {
  String sub;
  switch (state) {
    case SessionStateOrder.kDefault:
      sub = '...';  // waiting to connect
      break;
    case SessionStateOrder.kConnecting:
      sub = 'Connecting';
      break;
    case SessionStateOrder.kConnected:
      sub = 'Connected';
      break;
    case SessionStateOrder.kHandshaking:
      sub = 'Handshaking';
      break;
    case SessionStateOrder.kRunning:
      sub = '';  // normal running
      break;
    default:
      sub = 'Error';
      break;
  }
  return sub.isEmpty ? title : '$title ($sub)';
}


class StateMachine extends SessionStateMachine {
  StateMachine(super.session);

  SessionState? _currentState;

  @override
  SessionState? get currentState => _currentState;
  set currentState(SessionState? state) => _currentState = state;
}


class SharedSession extends ClientSession {
  SharedSession(super.station, super.remoteAddress, super.database) {
    fsm = StateMachine(this);
  }

  late final StateMachine fsm;

  @override
  set key(String? sessionKey) {
    super.key = sessionKey;
    ChannelManager channelManager = ChannelManager();
    channelManager.sessionChannel.setSessionKey(sessionKey);
  }

  @override
  SessionState get state {
    SessionState? current = fsm.currentState;
    return current ?? SessionState(SessionStateOrder.kError);
  }

  @override
  void start() {
    // TODO: implement start
  }

  @override
  void stop() {
    // TODO: implement stop
  }

  @override
  void pause() {
    // TODO: implement pause
  }

  @override
  void resume() {
    // TODO: implement resume
  }

  @override
  bool queueMessagePackage(ReliableMessage rMsg, Uint8List data, {int priority = 0}) {
    ChannelManager channelManager = ChannelManager();
    channelManager.sessionChannel.sendMessagePackage(rMsg, data, priority).then((value) {
      Log.debug('sent message package to channel');
    }).onError((error, stackTrace) {
      Log.error('failed to send message package to channel: $error');
    });
    return true;
  }

  @override
  bool sendResponse(Uint8List payload, Arrival ship, {required SocketAddress remote, SocketAddress? local}) {
    // TODO: implement sendResponse
    throw UnimplementedError();
  }

}
