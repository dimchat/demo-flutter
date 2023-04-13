import 'package:dim_client/dim_client.dart';
import 'package:flutter/services.dart';

class ChannelNames {

  static const session = 'chat.dim/session';
}

class ChannelMethods {

  //
  //  Session channel
  //
  static const sendMessagePackage = 'queueMessagePackage';
}

class ChannelManager {

  static final ChannelManager _instance = ChannelManager();

  static ChannelManager get instance => _instance;

  //
  //  Channels
  //
  final SessionChannel sessionChannel = SessionChannel(ChannelNames.session);
}

class SessionChannel extends MethodChannel {
  SessionChannel(super.name);

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
