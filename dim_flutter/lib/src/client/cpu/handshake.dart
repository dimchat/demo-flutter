
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/client.dart';

import '../shared.dart';


class ClientHandshakeProcessor extends HandshakeCommandProcessor {
  ClientHandshakeProcessor(super.facebook, super.messenger);

  static const String kTestSpeed = 'Nice to meet you!';
  static const String kTestSpeedRespond = 'Nice to meet you too!';

  static HandshakeCommand createTestSpeedCommand() =>
      BaseHandshakeCommand.from(kTestSpeed);

  // protected
  bool checkGreetingHandshake(HandshakeCommand content) {
    /// check for testing speed
    /// or greeting from other friend
    String title = content.title;
    if (title == kTestSpeedRespond) {
      logWarning('ignore test speed respond: $content');
      return true;
    } else if (title == kTestSpeed) {
      logError('unexpected test speed command: $content');
      // TODO: respond greeting
      return true;
    }
    return false;
  }

  // Handshake State
  // ~~~~~~~~~~~~~~~
  //    C -> S, start without session key(or session expired)
  //    S -> C, again with new session key
  //    C -> S, restart with new session key
  //    S -> C, handshake accepted

  // protected
  bool ignoredHandshake(HandshakeCommand content) {
    /// check duplicated message
    String title = content.title;
    if (title == 'DIM!') {
      //
      //    S -> C, handshake accepted
      //
      // don't ignore this.
      return false;
    } else if (title != 'DIM?') {
      //
      //    C -> S, start without session key(or session expired)
      //    C -> S, restart with new session key
      //
      assert(false, 'handshake command error: $content');
      // this command is sending from client to station,
      // it should not appear here, ignore it.
      return true;
    }
    //
    //    S -> C, again with new session key
    //
    String? newKey = content.sessionKey;
    if (newKey == null || newKey.isEmpty) {
      logError('handshake command error: $content');
      // ignore error command (should not happen)
      return true;
    }
    ClientSession? session = messenger?.session;
    if (session == null || !session.isReady) {
      logInfo('session not ready, handshake again: $content, ${session?.remoteAddress}');
      return false;
    }
    String? oldKey = session.sessionKey;
    if (oldKey == null) {
      logInfo('first handshake: ${session.remoteAddress}');
      return false;
    } else if (newKey != oldKey) {
      logWarning('session key changed: $oldKey -> $newKey');
      return false;
    }
    // Duplicated Condition
    // ~~~~~~~~~~~~~~~~~~~~
    //    1. session is ready
    //    2. new key == old key
    logWarning('duplicated session key: $newKey, ${session.remoteAddress}');
    DateTime? now = DateTime.now();
    DateTime? lastTime = _lastDuplicatedTime;
    if (lastTime == null) {
      logInfo('first duplicated, let it go: $newKey');
    } else if (lastTime.add(_delta).isAfter(now)) {
      // now < last + 5s
      // FIXME: why this happen?
      logWarning('ignore duplicated handshake: $session');
      return true;
    }
    // mark down last duplicated time
    _lastDuplicatedTime = now;
    return false;
  }
  DateTime? _lastDuplicatedTime;
  final Duration _delta = const Duration(seconds: 5);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is HandshakeCommand, 'handshake command error: $content');
    HandshakeCommand command = content as HandshakeCommand;
    logInfo('checking handshake command: ${rMsg.sender} -> $command');
    if (checkGreetingHandshake(command)) {
      logDebug('greeting handshake command processed: $command');
      return [];
    } else if (ignoredHandshake(command)) {
      logDebug('duplicated / error handshake command: $command');
      return [];
    }
    GlobalVariable shared = GlobalVariable();
    if (shared.isBackground == true) {
      logWarning('App Lifecycle: ignore handshake in background mode: $content');
      return [];
    }
    return await super.processContent(content, rMsg);
  }

}
