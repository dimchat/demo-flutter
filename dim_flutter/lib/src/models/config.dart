import 'package:flutter/services.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../filesys/external.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../widgets/browser.dart';

class Config {
  factory Config() => _instance;
  static final Config _instance = Config._internal();
  Config._internal();

  // TODO: start a background thread to query 'https://dim.chat/sechat/gsp.js'
  //       for updating configurations
  static String entrance = 'https://raw.githubusercontent.com/dimchat/'
      'demo-flutter/main/sechat/assets/config.json';

  Map? _info;

  Future<Map> get info async {
    Map? conf = _info;
    if (conf == null) {
      String path = await _path();
      conf = await _load(path);
      conf ??= await _init(path);
      // update for next reading
      Uri? url = Browser.parseUri(entrance);
      if (url == null) {
        Log.error('entrance url error: $entrance');
      } else {
        _refresh(url, path).onError((error, stackTrace) {
          Log.error('failed to update config: $entrance, $error, $stackTrace');
          return null;
        });
      }
    }
    return conf!;
  }

  Future<List> get stations async => (await info)['stations'];

  // 'http://106.52.25.169:8081/{ID}/upload?md5={MD5}&salt={SALT}'
  Future<List> get uploadAPI async => (await info)['uploads'];
  // TODO: update for secret key
  Future<String> get uploadKey async => '12345678';

  /// Home Page
  Future<String> get aboutURL async => (await info)['about']
      ?? 'https://dim.chat/';

  /// Terms Web Page
  Future<String> get termsURL async => (await info)['terms']
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
    return await ExternalStorage.loadJson(path);
  } else {
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
    await ExternalStorage.saveJson(conf, path);
  }
  return conf;
}

/// refresh config info to caches path from remote URL
Future<Map?> _refresh(Uri url, String path) async {
  // 1. download from remote URL
  ChannelManager man = ChannelManager();
  String? tmp = await man.ftpChannel.downloadFile(url);
  if (tmp == null) {
    Log.error('failed to download config: $url');
    return null;
  } else {
    Log.debug('download config: $url -> $tmp');
  }
  // 2. check config
  Map? conf;
  try {
    conf = await ExternalStorage.loadJson(tmp);
    if (conf == null) {
      Log.warning('config not exists: $tmp');
      return null;
    }
  } catch (e) {
    Log.error('failed to load config: $e');
    return null;
  }
  ID? gsp = ID.parse(conf['ID']);
  List? stations = conf['stations'];
  List? uploads = conf['uploads'];
  if (gsp == null || stations == null || uploads == null) {
    Log.error('config error: $conf');
    return null;
  } else if (stations.isEmpty || uploads.isEmpty) {
    Log.error('config error: $conf');
    return null;
  }
  // 3. replace config
  Log.warning('replace config: $tmp => $path, $conf');
  await ExternalStorage.saveJson(conf, path);
  return conf;
}
