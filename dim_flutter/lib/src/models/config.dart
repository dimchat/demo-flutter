import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart' as lnc;
import 'package:pnf/dos.dart';
import 'package:pnf/pnf.dart' show PortableNetworkLoader;

import '../client/client.dart';
import '../client/shared.dart';
import '../common/constants.dart';
import '../common/platform.dart';
import '../filesys/local.dart';
import '../pnf/loader.dart';
import '../pnf/net_base.dart';
import '../ui/styles.dart';
import '../utils/html.dart';
import '../widgets/alert.dart';
import '../widgets/browser.dart';
import '../widgets/gaussian.dart';


class _ConfigLoader with Logging implements lnc.Observer {
  _ConfigLoader() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceiveProgress);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceived);
    nc.addObserver(this, NotificationNames.kPortableNetworkDecrypted);
    nc.addObserver(this, NotificationNames.kPortableNetworkSuccess);
    nc.addObserver(this, NotificationNames.kPortableNetworkError);
  }

  PortableNetworkLoader? _pnfLoader;

  Map? info;

  Future<void> download(Uri url) async {
    PortableNetworkFile pnf = PortableNetworkFile.createFromURL(url, null);
    // 1. remove cached files
    PortableNetworkLoader loader = PortableFileLoader(pnf);
    String? path = await loader.cacheFilePath;
    if (path != null) {
      logInfo('remove cached config file: $path');
      await Paths.delete(path);
    }
    path = await loader.downloadFilePath;
    if (path != null) {
      logInfo('remove cached config file: $path');
      await Paths.delete(path);
    }
    // 2. download again
    _pnfLoader = PortableNetworkFactory().getLoader(pnf);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (notification.sender != _pnfLoader) {
      return;
    } else if (name == NotificationNames.kPortableNetworkSuccess) {
      Uri? url = userInfo?['URL'];
      Uint8List? data = userInfo?['data'];
      String? path = await _pnfLoader?.cacheFilePath;
      logInfo('[PNF] onSuccess: ${data?.length} bytes, $url');
      await _refresh(data, path);
    }
  }

  Future<bool> _refresh(Uint8List? data, String? path) async {
    String configPath = await _path();
    if (data == null || configPath == path) {
      assert(false, 'should not happen: ${data?.length} bytes, $path -> $configPath');
      return false;
    }
    int cnt = await ExternalStorage.saveBinary(data, configPath);
    assert(cnt == data.length, 'failed to save config file: $cnt/${data.length}, $configPath');
    String? text = UTF8.decode(data);
    if (text == null) {
      assert(false, 'data error :${data.length} bytes');
      return false;
    }
    info = JSON.decode(text);
    logInfo('new config: $text');
    var nc = lnc.NotificationCenter();
    nc.postNotification(NotificationNames.kConfigUpdated, this, {
      'config': text,
    });
    return true;
  }

}

class Config with Logging {
  factory Config() => _instance;
  static final Config _instance = Config._internal();
  Config._internal();

  // TODO: start a bg-thread to query 'http://tarsier.dim.chat/config.json'
  //       for updating configurations
  static String entrance = 'http://tarsier.dim.chat/v1/config.json';

  final _cfgLoader = _ConfigLoader();

  Future<Map> get _info async {
    Map? conf = _cfgLoader.info;
    if (conf == null) {
      String path = await _path();
      conf = await _load(path);
      conf ??= await _init(path);
      // update for next reading
      Uri? url = entrance.isEmpty ? null : HtmlUri.parseUri(entrance);
      if (entrance.isEmpty) {
        logDebug('config.json already downloaded');
      } else if (url == null) {
        logError('entrance url error: $entrance');
      } else {
        logInfo('try to refresh config: $url -> $path');
        entrance = '';
        /*await */_cfgLoader.download(url);
      }
    }
    return conf ?? {};
  }

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz url="$entrance">\n${_cfgLoader.info}\n</$clazz>';
  }

  /// Default contacts
  Future<List<ID>> get contacts async {
    List? array = (await _info)['contacts'];
    if (array == null || array.isEmpty) {
      return [];
    }
    List<ID> users = [];
    ID? uid;
    for (var item in array) {
      if (item is Map) {
        uid = ID.parse(item['ID']);
      } else {
        uid = ID.parse(item);
      }
      if (uid != null) {
        users.add(uid);
      }
    }
    return users;
  }

  /// Common assistants for group
  Future<List<ID>> get assistants async {
    List? array = (await _info)['assistants'];
    if (array == null || array.isEmpty) {
      return [];
    }
    List<ID> bots = [];
    ID? uid;
    for (var item in array) {
      if (item is Map) {
        uid = ID.parse(item['ID']);
      } else {
        uid = ID.parse(item);
      }
      if (uid != null) {
        bots.add(uid);
      }
    }
    return bots;
  }

  /// Service Bots
  Future<List> get services async => (await _info)['services'] ?? [];

  Future<ID?> get provider async => ID.parse((await _info)['ID']);

  /// Base stations
  Future<List> get stations async => (await _info)['stations'] ?? [];

  // 'http://106.52.25.169:8081/{ID}/upload?md5={MD5}&salt={SALT}'
  Future<List> get uploadAPI async => (await _info)['uploads'] ?? [];
  // Future<String> get uploadKey async => '12345678';

  /// Open Source
  Future<String> get sourceURL async => (await _info)['sources']
      ?? 'https://github.com/dimpart/tarsier';

  /// Terms Web Page
  Future<String> get termsURL async => (await _info)['terms']
      ?? 'https://wallet.dim.chat/dimchat/sechat/privacy.html';

  /// Home Page
  Future<String> get aboutURL async => (await _info)['about']
      ?? 'https://dim.chat/';

  Newest? get newest => NewestManager().parse(_cfgLoader.info);

}


class NewestManager with Logging {
  factory NewestManager() => _instance;
  static final NewestManager _instance = NewestManager._internal();
  NewestManager._internal();

  Newest? _latest;

  int _remind = 0;
  // remind level
  static const int kCanUpgrade = 1;
  static const int kShouldUpgrade = 2;
  static const int kMustUpgrade = 3;

  // App Distribution Channel
  String store = 'AppStore';  // AppStore, GooglePlay, ...

  Newest? parse(Map? info) {
    Newest? newest = _latest;
    if (newest != null) {
      return newest;
    } else if (info == null) {
      return null;
    }
    // get newest info
    var child = info['newest'];
    if (child is Map) {
      info = child;
    } else {
      // check for URL?
      return null;
    }
    // check OS
    var os = DevicePlatform.operatingSystem;
    var ver = os.toLowerCase();
    var cid = store.toLowerCase();
    /// 'android-amazon' > 'android'
    info = info['$ver-$cid'] ?? info[ver] ?? info;
    logInfo('got newest for channel "$os-$store": $info');
    if (info is Map) {
      _latest = newest = Newest.from(info);
    }
    if (newest != null) {
      GlobalVariable shared = GlobalVariable();
      Client client = shared.terminal;
      if (newest.mustUpgrade(client)) {
        _remind = kMustUpgrade;
      } else if (newest.shouldUpgrade(client)) {
        _remind = kShouldUpgrade;
      } else if (newest.canUpgrade(client)) {
        _remind = kCanUpgrade;
      } else {
        _remind = 0;
      }
    }
    return newest;
  }

  bool checkUpdate(BuildContext context) {
    Newest? newest = _latest;
    int level = _remind;
    if (newest == null) {
      return false;
    } else if (level > 0) {
      _remind = 0;
    } else {
      return false;
    }
    String notice = 'Please update app (@version, build @build).'.trParams({
      'version': newest.version,
      'build': newest.build.toString(),
    });
    if (level == kShouldUpgrade) {
      Alert.confirm(context, 'Upgrade', notice,
        okAction: () => Browser.launch(context, newest.url),
      );
    } else if (level == kMustUpgrade) {
      FrostedGlassPage.lock(context, title: 'Upgrade'.tr, body: RichText(
        text: TextSpan(
          text: notice,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: Styles.colors.secondaryTextColor,
            decoration: TextDecoration.none,
          ),
        ),
      ), tail: TextButton(
        onPressed: () => Browser.launch(context, newest.url),
        child: Text('Download'.tr, style: TextStyle(
          color: Styles.colors.criticalButtonColor,
          decoration: TextDecoration.underline,
          // decorationStyle: TextDecorationStyle.double,
          decorationColor: Styles.colors.criticalButtonColor,
        ),),
      ));
    }
    return true;
  }

}


/// Newest client info
class Newest {
  Newest({required this.version, required this.build, required this.url});

  final String version;
  final int build;
  final String url;

  bool mustUpgrade(Client client) {
    if (int.parse(client.buildNumber) >= build) {
      // it is the latest build
      return false;
    }
    String clientVersion = client.versionName;
    int pos = clientVersion.indexOf(r'.');
    if (pos <= 0) {
      // version error
      return false;
    }
    // if the client has a different major version number,
    // it must be upgraded now.
    clientVersion = clientVersion.substring(0, pos);
    return !version.startsWith(clientVersion);
  }

  bool shouldUpgrade(Client client) {
    if (int.parse(client.buildNumber) >= build) {
      // it is the latest build
      return false;
    }
    String clientVersion = client.versionName;
    int pos = clientVersion.lastIndexOf(r'.');
    if (pos <= 0) {
      // version error
      return false;
    }
    // if the client has a same major version number,
    // but a different minor version number,
    // it should be upgraded now.
    clientVersion = clientVersion.substring(0, pos);
    return !version.startsWith(clientVersion);
  }

  bool canUpgrade(Client client) =>
      int.parse(client.buildNumber) < build;

  static Newest? from(Map info) {
    String? version = info['version'];
    int? build = info['build'];
    String? url = info['url'] ?? info['URL'];
    if (version == null || build == null || url == null) {
      return null;
    } else if (!url.contains('://')) {
      assert(false, 'client download URL error: $info');
      return null;
    }
    return Newest(version: version, build: build, url: url);
  }

}


/// get caches path for 'config.json'
Future<String> _path() async {
  String dir = await LocalStorage().cachesDirectory;
  return Paths.append(dir, 'config.json');
}

/// load config info from caches path
Future<Map?> _load(String path) async {
  if (await Paths.exists(path)) {
    // file exists, trying to load
  } else {
    return null;
  }
  try {
    return await ExternalStorage.loadJsonMap(path);
  } catch (e, st) {
    Log.error('failed to load config: $path, $e, $st');
    return null;
  }
}

/// init config info to caches path
Future<Map?> _init(String path) async {
  String json = await rootBundle.loadString('assets/config.json');
  Map? conf = JSONMap.decode(json);
  if (conf == null) {
    assert(false, 'config error: $json');
  } else {
    Log.warning('initialize config: $path, $conf');
    await ExternalStorage.saveJsonMap(conf, path);
  }
  return conf;
}
