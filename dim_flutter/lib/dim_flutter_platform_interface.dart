import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dim_flutter_method_channel.dart';

abstract class DimFlutterPlatform extends PlatformInterface {
  /// Constructs a DimFlutterPlatform.
  DimFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static DimFlutterPlatform _instance = MethodChannelDimFlutter();

  /// The default instance of [DimFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelDimFlutter].
  static DimFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DimFlutterPlatform] when
  /// they register themselves.
  static set instance(DimFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
