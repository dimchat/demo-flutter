import 'package:flutter/services.dart';

import 'package:dim_client/ok.dart';

import '../common//constants.dart';
import 'manager.dart';

class AudioChannel extends SafeChannel {
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

  Future<void> startRecord() async =>
      await invoke(ChannelMethods.startRecord, null);

  Future<void> stopRecord() async =>
      await invoke(ChannelMethods.stopRecord, null);

  Future<void> startPlay(String path) async =>
      await invoke(ChannelMethods.startPlay, {
        'path': path,
      });

  Future<void> stopPlay(String? path) async =>
      await invoke(ChannelMethods.stopPlay, {
        'path': path,
      });

}
