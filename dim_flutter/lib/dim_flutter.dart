library dim_flutter;

export 'package:dim_client/ok.dart';
// export 'package:dim_client/ws.dart';
export 'package:dim_client/sdk.dart';
export 'package:dim_client/sqlite.dart';
export 'package:dim_client/plugins.dart';

export 'package:dim_client/compat.dart';
export 'package:dim_client/common.dart';
export 'package:dim_client/network.dart';
export 'package:dim_client/group.dart';
export 'package:dim_client/client.dart';
export 'package:dim_client/cpu.dart';

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
export 'src/dim_utils.dart';
export 'src/dim_video.dart';
export 'src/dim_web3.dart';
export 'src/dim_widgets.dart';


import 'dim_flutter_platform_interface.dart';

class DimFlutter {
  Future<String?> getPlatformVersion() {
    return DimFlutterPlatform.instance.getPlatformVersion();
  }
}
