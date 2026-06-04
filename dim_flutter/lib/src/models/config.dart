import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;

import '../common/constants.dart';
import '../filesys/upload.dart';

import 'config_api.dart';
import 'config_loader.dart';
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
    String clazz = className;
    return '<$clazz url="$entrance">\n$_info\n</$clazz>';
  }

  /// Web masters
  List<ID> get managers {
    var array = _info?['managers'];
    return _IDUtils.convert(array);
  }

  /// Default contacts
  List<ID> get contacts {
    var array = _info?['contacts'];
    return _IDUtils.convert(array);
  }

  /// Service bots for translation
  List<ID> get translators {
    var array = _info?['translators'];
    return _IDUtils.convert(array);
  }

  /// Service Bots
  List get services {
    var array = _info?['services'];
    if (array is List) {
      return array;
    }
    assert(array == null, 'services error: $array');
    return [];
  }
  // List get services => _info?['services'] ?? [];

  ID? get provider => _IDUtils.getIdentifier(_info);

  /// Base stations
  List get stations {
    var array = _info?['stations'];
    if (array is List) {
      return array;
    }
    assert(array == null, 'stations error: $array');
    return [];
  }
  // List get stations => _info?['stations'] ?? [];

  UploadServer? get uploadAvatarAPI => _UploadAPI(_info ?? {}).uploadAvatarAPI;
  UploadServer? get uploadFileAPI => _UploadAPI(_info ?? {}).uploadFileAPI;

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
      var loader = ConfigLoader();
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
  // update file uploader
  var ftp = SharedFileUploader();
  ftp.initWithConfig(config);
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

  UploadServer? _fastestAPI(List apiList) {
    List<UploadServer> array = UploadServer.convert(apiList);
    // TODO: choose the fastest URL
    return array.isEmpty ? null : array.first;
  }

  //
  //  APIs
  //
  UploadServer? get uploadAvatarAPI => _fastestAPI(avatars);
  UploadServer? get uploadFileAPI   => _fastestAPI(files);

}



abstract interface class _IDUtils {

  static List<ID> convert(dynamic array) {
    if (array == null || array is! List) {
      return [];
    }
    List<ID> users = [];
    ID? uid;
    for (var item in array) {
      uid = getIdentifier(item);
      if (uid != null) {
        users.add(uid);
      }
    }
    return users;
  }

  static ID? getIdentifier(dynamic info) {
    if (info == null) {
      return null;
    } else if (info is Map) {
      info = info['did'] ?? info['ID'];
    }
    return ID.parse(info);
  }

}
