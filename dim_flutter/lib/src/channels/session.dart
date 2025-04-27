import 'package:flutter/services.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../widgets/permissions.dart';
import '../client/client.dart';
import '../client/messenger.dart';
import '../client/shared.dart';
import 'manager.dart';

class SessionChannel extends SafeChannel {
  SessionChannel(super.name) {
    setMethodCallHandler(_handle);
  }

  /// MethCallHandler
  Future<void> _handle(MethodCall call) async {
    String method = call.method;
    var arguments = call.arguments;
    if (method == ChannelMethods.sendContent) {
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
    if (content is ReportCommand) {
      String? title = content.title;
      if (title == 'apns' || title == 'c2dm') {
        Log.info('checking notification permissions for command: $content');
        PermissionChecker().setNeedsNotificationPermissions();
      }
    }
    _sendContent(content, sender: sender, receiver: receiver, priority: priority);
  }

  void _sendContent(Content content, {ID? sender, required ID receiver, int priority = 0}) {
    GlobalVariable shared = GlobalVariable();
    Client client = shared.terminal;
    Log.info('[safe channel] sending content: $sender => $receiver: $content');
    client.addWaitingContent(content, receiver: receiver, priority: priority);
  }

}
