import 'package:flutter/services.dart';

import 'manager.dart';

class SessionChannel extends SafeChannel {
  SessionChannel(super.name) {
    setMethodCallHandler(_handle);
  }

  /// MethCallHandler
  Future<void> _handle(MethodCall call) async {
  }

  /// pack message payload to network package
  Future<Uint8List?> packData(Uint8List payload) async =>
      await invoke(ChannelMethods.packData, {
        'payload': payload,
      });

  /// unpack payload from network package
  Future<Map?> unpackData(Uint8List data) async =>
      await invoke(ChannelMethods.unpackData, {
        'data': data,
      });

}
