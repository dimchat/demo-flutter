library dim_flutter;

export 'package:dim_client/dim_client.dart';
export 'package:lnc/log.dart';

export 'src/dim_channels.dart';
export 'src/dim_client.dart';
export 'src/dim_common.dart';
export 'src/dim_filesys.dart';
export 'src/dim_models.dart';
export 'src/dim_network.dart';
export 'src/dim_pnf.dart' hide NotificationNames;
export 'src/dim_screens.dart';
export 'src/dim_sqlite.dart';
export 'src/dim_ui.dart';
export 'src/dim_video.dart';
export 'src/dim_web3.dart';
export 'src/dim_widgets.dart';


import 'dim_flutter_platform_interface.dart';

class DimFlutter {
  Future<String?> getPlatformVersion() {
    return DimFlutterPlatform.instance.getPlatformVersion();
  }
}
