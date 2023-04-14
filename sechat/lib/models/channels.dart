import 'package:dim_client/dim_client.dart';
import 'package:flutter/services.dart';

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
  static const String getState = 'getState';
  static const String sendMessagePackage = "queueMessagePackage";

  static const String onStateChanged = 'onStateChanged';

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
        Log.warning('onStateChanged: $previous -> $current');
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
