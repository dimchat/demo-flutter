import 'package:flutter_test/flutter_test.dart';
import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/dim_flutter_platform_interface.dart';
import 'package:dim_flutter/dim_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDimFlutterPlatform
    with MockPlatformInterfaceMixin
    implements DimFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DimFlutterPlatform initialPlatform = DimFlutterPlatform.instance;

  test('$MethodChannelDimFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDimFlutter>());
  });

  test('getPlatformVersion', () async {
    DimFlutter dimFlutterPlugin = DimFlutter();
    MockDimFlutterPlatform fakePlatform = MockDimFlutterPlatform();
    DimFlutterPlatform.instance = fakePlatform;

    expect(await dimFlutterPlugin.getPlatformVersion(), '42');
  });
}
