import 'package:flutter/services.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../filesys/external.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../widgets/browse_html.dart';

class Config {
  factory Config() => _instance;
  static final Config _instance = Config._internal();
  Config._internal();

  // TODO: start a bg-thread to query 'http://tarsier.dim.chat/config.json'
  //       for updating configurations
  static String entrance = 'http://tarsier.dim.chat/v1/config.json';

  Map? _info;

  Future<Map?> get info async {
    Map? conf = _info;
    if (conf == null) {
      String? path = await _path();
      if (path == null) {
        Log.error('failed to get path for config.json');
        return null;
      }
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
        _refresh(url, path).then((value) {
          if (value == null) {
            Log.error('failed to refresh config: $url, $path');
          } else {
            Log.info('config reloaded: $path');
            _info = value;
          }
        }).onError((error, stackTrace) {
          Log.error('failed to update config: $entrance, $error, $stackTrace');
          return null;
        });
      }
    }
    return conf;
  }

  /// Default contacts
  Future<List<ID>> get contacts async {
    List? array = (await info)?['contacts'];
    return array == null ? [] : ID.convert(array);
  }

  Future<ID?> get provider async => ID.parse((await info)?['ID']);

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
Future<String?> _path() async {
  String? dir = await LocalStorage().cachesDirectory;
  if (dir == null) {
    return null;
  }
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

/// refresh config info to caches path from remote URL
Future<Map?> _refresh(Uri url, String path) async {
  // 1. download from remote URL
  ChannelManager man = ChannelManager();
  String? tmp = await man.ftpChannel.downloadFile(url);  // FIXME: replace with dio
  if (tmp == null) {
    Log.error('failed to download config: $url');
    return null;
  } else {
    Log.debug('download config: $url -> $tmp');
  }
  // get config from temporary file
  Map? conf;
  try {
    conf = await ExternalStorage.loadJsonMap(tmp);
  } catch (e, st) {
    Log.error('downloaded config error: $e, $st');
    conf = null;
  }
  // remove temporary file
  if (await Paths.delete(tmp)) {
    Log.debug('temporary config file removed: $tmp');
  }
  // 2. check config
  if (conf == null) {
    Log.warning('failed to load config: $tmp');
    return null;
  }
  ID? provider = ID.parse(conf['ID']);
  List? stations = conf['stations'];
  List? uploads = conf['uploads'];
  if (provider == null || stations == null || uploads == null) {
    Log.error('not a config: $conf');
    return null;
  } else if (stations.isEmpty || uploads.isEmpty) {
    Log.error('config error: $conf');
    return null;
  }
  // 3. replace config
  Log.warning('replace config file: $path, $conf');
  await ExternalStorage.saveJsonMap(conf, path);
  return conf;
}


/// Enigma for MD5 secrets
class Enigma {
  factory Enigma() => _instance;
  static final Enigma _instance = Enigma._internal();
  Enigma._internal();

  Map? _info;

  Future<Map?> get info async {
    if (_info == null) {
      String json = await rootBundle.loadString('assets/enigma.json');
      _info = JSONMap.decode(json);
    }
    return _info;
  }

  Future<String?> getSecret(String enigma) async {
    Map? conf = await info;
    var secrets = conf?['secrets'];
    if (secrets is! List) {
      assert(false, 'enigma.json error: $conf');
      return null;
    }
    if (enigma.isEmpty) {
      // any secret?
      return secrets.first;
    }
    for (String hex in secrets) {
      if (hex.startsWith(enigma)) {
        assert(hex.length > enigma.length, 'enigma error: $enigma');
        return hex;
      }
    }
    assert(false, 'secret not found: $enigma');
    return null;
  }

}
