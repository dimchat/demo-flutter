
import 'dim_flutter_platform_interface.dart';

class DimFlutter {
  Future<String?> getPlatformVersion() {
    return DimFlutterPlatform.instance.getPlatformVersion();
  }
}
