import 'package:flutter/services.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/group.dart';

import 'package:pnf/dos.dart';
import 'package:pnf/enigma.dart';
import 'package:pnf/http.dart';

import '../common/constants.dart';
import '../filesys/local.dart';
import '../filesys/upload.dart';
import '../utils/html.dart';
import 'newest.dart';


class Config with Logging {
  factory Config() => _instance;
  static final Config _instance = Config._internal();
  Config._internal();

  // TODO: start a bg-thread to query 'http://tarsier.dim.chat/config.json'
  //       for updating configurations
  static const String entrance = 'http://tarsier.dim.chat/v1/config.json';

  static const String assets = 'assets/config.json';

  Map? _info;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz url="$entrance">\n$_info\n</$clazz>';
  }

  ID? get webmaster {
    var admin = _info?['webmaster'];
    return ID.parse(admin);
  }

  /// Default contacts
  List<ID> get contacts {
    List? array = _info?['contacts'];
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

  /// Service bots for translation
  List<ID> get translators {
    List? array = _info?['translators'];
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

  /// Common assistants for group
  List<ID> get assistants {
    List? array = _info?['assistants'];
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
  List get services => _info?['services'] ?? [];

  ID? get provider => ID.parse(_info?['ID']);

  /// Base stations
  List get stations => _info?['stations'] ?? [];

  // 'http://tfs.dim.chat:8081/upload/{ID}/avatar?md5={MD5}&salt={SALT}&enigma=123456'
  // 'http://106.52.25.169:8081/upload/{ID}/file?md5={MD5}&salt={SALT}&enigma=123456'
  String? get uploadAvatarAPI => _UploadAPI(_info ?? {}).uploadAvatarAPI;
  String? get uploadFileAPI => _UploadAPI(_info ?? {}).uploadFileAPI;

  /// Open Source
  String get sourceURL => _info?['sources']
      ?? 'https://github.com/dimpart/tarsier';

  /// Terms Web Page
  String get termsURL => _info?['terms']
      ?? 'http://tarsier.dim.chat/v1/docs/terms.html';
  String get privacyURL => _info?['privacy']
      ?? 'http://tarsier.dim.chat/v1/docs/privacy.html';

  /// Home Page
  String get aboutURL => _info?['about']
      ?? 'https://dim.chat/';

  Newest? get newest => NewestManager().parse(_info);

  Future<Config> load() async {
    Map? cnf = _info;
    if (cnf == null) {
      _info = {};
      //
      //  1. load from cache path
      //
      var loader = _ConfigLoader();
      cnf = await loader.loadConfig();
      //
      //  2. if cache not found, load from assets
      //
      cnf ??= await loader.loadAssetsFile(assets);
      _info = cnf;
      //
      //  3. download to update
      //
      loader.downloadConfig(entrance).then((dict) {
        if (dict != null) {
          // 3.1 update cache
          _info = dict;
          loader.saveConfig(dict);
          // 3.2 refresh
          _initWithConfig(this);
          // 3.3 post notification
          var nc = lnc.NotificationCenter();
          nc.postNotification(NotificationNames.kConfigUpdated, loader, {
            'config': dict,
          });
        }
      });
    }
    _initWithConfig(this);
    return this;
  }

}

void _initWithConfig(Config config) {
  // update group assistants
  var bots = config.assistants;
  if (bots.isNotEmpty) {
    SharedGroupManager man = SharedGroupManager();
    man.delegate.setCommonAssistants(bots);
  }
  // update file uploader
  var ftp = SharedFileUploader();
  ftp.initWithConfig(config);
}


class _ConfigLoader with Logging {

  Future<Map> loadAssetsFile(String assets) async {
    String json = await rootBundle.loadString(assets);
    var cnf = JSONMap.decode(json);
    if (cnf == null) {
      assert(false, 'config assets error: $assets -> $json');
      cnf = {};
    }
    return cnf;
  }

  Future<String> _cachePath() async {
    String dir = await LocalStorage().cachesDirectory;
    return Paths.append(dir, 'config.json');
  }

  Future<Map?> loadConfig() async {
    String path = await _cachePath();
    if (await Paths.exists(path)) {
      // file exists, trying to load
      return await ExternalStorage.loadJsonMap(path);
    } else {
      logError('config file not exists: $path');
      return null;
    }
  }

  Future<bool> saveConfig(Map cnf) async {
    String path = await _cachePath();
    try {
      int size = await ExternalStorage.saveJsonMap(cnf, path);
      return size > 0;
    } catch (e, st) {
      logError('failed to save config: $path, $e, $st');
      return false;
    }
  }

  Future<Map?> downloadConfig(String entrance) async {
    var url = HtmlUri.parseUri(entrance);
    if (url == null) {
      assert(false, 'config URL error: $entrance');
      return null;
    }
    var http = FileDownloader(HTTPClient());
    Uint8List? data = await http.download(url);
    if (data == null) {
      logWarning('failed to download config: $url');
      return null;
    }
    String? text = UTF8.decode(data);
    if (text == null) {
      assert(false, 'data error: ${data.length} bytes');
      return null;
    }
    Map? cnf = JSONMap.decode(text);
    if (cnf == null) {
      assert(false, 'config error: $text');
      return null;
    }
    logInfo('new config: $text');
    return cnf;
  }

}


class _UploadAPI with Logging {
  _UploadAPI(this._info);

  final Map _info;

  List get avatars => _fetch('avatar');

  List get files => _fetch('file');

  List _fetch(String name) {
    var info = _info['upload'] ?? _info;
    info = info['uploads'] ?? info[name];
    return info is List ? info : [];
  }

  String? _fastestAPI(List apiList) {
    List<String> array = _APIUtils.fetch(apiList);
    // TODO: choose the fastest URL
    return array.isEmpty ? null : array.first;
  }

  //
  //  APIs
  //
  String? get uploadAvatarAPI => _fastestAPI(avatars);
  String? get uploadFileAPI   => _fastestAPI(files);

}


abstract interface class _APIUtils {

  static List<String> fetch(List apiList) {
    List<String> array = [];
    String? item;
    for (var api in apiList) {
      if (api is String && api.contains('://')) {
        array.add(api);
      } else if (api is Map) {
        item = join(api);
        if (item != null) {
          array.add(item);
        }
      }
    }
    return array;
  }

  static String? join(Map api) {
    String? url = api['url'] ?? api['URL'];
    if (url == null) {
      assert(false, 'api error: $api');
      return null;
    }
    String? enigma = api['enigma'];
    return enigma == null ? url : Template.replaceQueryParam(url, 'enigma', enigma);
  }

}
