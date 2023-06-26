import 'package:flutter/services.dart';
import 'package:lnc/lnc.dart';

import '../client/constants.dart';
import 'manager.dart';

class AudioChannel extends MethodChannel {
  AudioChannel(super.name) {
    setMethodCallHandler(_handle);
  }

  /// MethodCallHandler
  Future<void> _handle(MethodCall call) async {
    String method = call.method;
    var arguments = call.arguments;
    if (method == ChannelMethods.onRecordFinished) {
      // onRecordFinished
      Uint8List mp4 = arguments['data'];
      double duration = arguments['current'];
      // post notification async
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kRecordFinished, this, {
        'data': mp4,
        'duration': duration,
      });
    } else if (method == ChannelMethods.onPlayFinished) {
      // onPlayFinished
      String? path = arguments['path'];
      // post notification async
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kPlayFinished, this, {
        'path': path,
      });
    }
  }

  //
  //  Invoke Methods
  //
  Future<dynamic> _invoke(String method, dynamic arguments) async {
    try {
      return await invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      Log.error('channel error: $e');
      return;
    }
  }

  Future<void> startRecord() async =>
      await _invoke(ChannelMethods.startRecord, null);

  Future<void> stopRecord() async =>
      await _invoke(ChannelMethods.stopRecord, null);

  Future<void> startPlay(String path) async =>
      await _invoke(ChannelMethods.startPlay, {
        'path': path,
      });

  Future<void> stopPlay(String? path) async =>
      await _invoke(ChannelMethods.stopPlay, {
        'path': path,
      });

}
