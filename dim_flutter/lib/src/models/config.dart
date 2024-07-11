import 'package:flutter/services.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart' as lnc;
import 'package:pnf/dos.dart';
import 'package:pnf/pnf.dart' show PortableNetworkLoader;

import '../common/constants.dart';
import '../filesys/local.dart';
import '../pnf/loader.dart';
import '../pnf/net_base.dart';
import '../widgets/browse_html.dart';


class _ConfigLoader implements lnc.Observer {
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
      Log.info('remove cached config file: $path');
      await Paths.delete(path);
    }
    path = await loader.downloadFilePath;
    if (path != null) {
      Log.info('remove cached config file: $path');
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
      Log.info('[PNF] onSuccess: ${data?.length} bytes, $url');
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
    Log.info('new config: $text');
    return true;
  }

}

class Config {
  factory Config() => _instance;
  static final Config _instance = Config._internal();
  Config._internal();

  // TODO: start a bg-thread to query 'http://tarsier.dim.chat/config.json'
  //       for updating configurations
  static String entrance = 'http://tarsier.dim.chat/v1/config.json';

  final _cfgLoader = _ConfigLoader();

  Future<Map?> get info async {
    Map? conf = _cfgLoader.info;
    if (conf == null) {
      String path = await _path();
      conf = await _load(path);
      conf ??= await _init(path);
      // update for next reading
      Uri? url = entrance.isEmpty ? null : HtmlUri.parseUri(entrance);
      if (entrance.isEmpty) {
        Log.debug('config.json already downloaded');
      } else if (url == null) {
        Log.error('entrance url error: $entrance');
      } else {
        Log.info('try to refresh config: $url -> $path');
        entrance = '';
        /*await */_cfgLoader.download(url);
      }
    }
    return conf;
  }

  /// Default contacts
  Future<List<ID>> get contacts async {
    List? array = (await info)?['contacts'];
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
  Future<List<ID>?> get assistants async {
    List? array = (await info)?['assistants'];
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
  Future<List<dynamic>?> get services async => (await info)?['services'];

  Future<ID?> get provider async => ID.parse((await info)?['ID']);

  /// Base stations
  Future<List?> get stations async => (await info)?['stations'];

  // 'http://106.52.25.169:8081/{ID}/upload?md5={MD5}&salt={SALT}'
  Future<List> get uploadAPI async => (await info)?['uploads'];
  // Future<String> get uploadKey async => '12345678';

  /// Home Page
  Future<String> get aboutURL async => (await info)?['about']
      ?? 'https://dim.chat/';

  /// Terms Web Page
  Future<String> get termsURL async => (await info)?['terms']
      ?? 'https://wallet.dim.chat/dimchat/sechat/privacy.html';
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
