import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dim_flutter_platform_interface.dart';

/// An implementation of [DimFlutterPlatform] that uses method channels.
class MethodChannelDimFlutter extends DimFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dim_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
