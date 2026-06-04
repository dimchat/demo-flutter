import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:pnf/dos.dart';
import 'package:pnf/http.dart';

import '../filesys/local.dart';
import '../utils/html.dart';


class ConfigBranch with Logging {
  ConfigBranch(this.config);

  final Map config;

  /// Fetch branch info
  ///
  ///   1. if the branch value is a URL, download it from the server;
  ///   2. if failed to download, load it from local storage.
  ///
  Future<dynamic> fetchBranch(String name) async {
    logInfo('checking config branch: $name');
    var value = config[name];
    if (value is List || value is Map) {
      //
      //  cache to local storage
      //
      bool ok = await _saveBranch(value, name);
      assert(ok, 'failed to save branch: $name');
      // value not changed, so
      // we return null here
      return null;
    } else if (value is String) {
      //
      //  download from URL
      //
      assert(value.indexOf('://') > 0, 'config branch error: "$name" -> $value');
      var info = await _downloadBranch(value, name);
      if (info == null) {
        // failed to download from remote URL,
        // load it from local storage
        info = await _loadBranch(name);
        assert(info != null, 'failed to load config branch: $name');
      } else {
        // download success,
        // update local storage
        bool ok = await _saveBranch(info, name);
        assert(ok, 'failed to save branch: $name');
      }
      return info;
    } else {
      assert(value == null, 'config branch error: "$name" -> $value');
      return null;
    }
  }

  Future<String> _cachePath(String name) async {
    // TODO: check filename for safety
    String dir = await LocalStorage().cachesDirectory;
    return Paths.append(dir, 'config.d', '$name.json');
  }

  /// Cache branch to local storage
  ///
  ///   path: 'files/config.d/{name}.json'
  ///
  ///   file content: {
  ///     name: info,
  ///   }
  Future<bool> _saveBranch(dynamic info, String name) async {
    //
    //  1. wrap
    //
    Map container;
    if (info is Map) {
      var inner = info[name];
      if (inner == null) {
        container = {name: info};
      } else {
        // already wrapped
        container = info;
      }
    } else {
      assert(info is List, 'config branch error: "$name", $info');
      container = {name: info};
    }
    //
    //  2. save
    //
    String path = await _cachePath(name);
    logInfo('saving config branch: "$name" -> $path');
    bool ok = await ConfigStorage.save(container, path);
    assert(ok, 'failed to save config branch: "$name" -> $path');
    return ok;
  }

  Future<dynamic> _loadBranch(String name) async {
    String path = await _cachePath(name);
    logInfo('loading config branch: "$name" -> $path');
    //
    //  1. load
    //
    Map? info = await ConfigStorage.load(path);
    assert(info != null, 'config branch not found: "$name" -> $path');
    //
    //  2. unwrap
    //
    var inner = info?[name];
    if (inner != null) {
      // the config branch (json in local storage)
      // must be a map with the 'name' as its root level key
      return inner;
    }
    assert(false, 'config branch error: "$name" -> $path, $info');
    return info;
  }

  Future<dynamic> _downloadBranch(String remote, String name) async {
    logInfo('downloading config branch: "$name", $remote');
    //
    //  1. download
    //
    var info = await ConfigServer.download(remote);
    assert(info != null, 'config branch not found: "$name" -> $remote');
    //
    //  2. unwrap
    //
    if (info is Map) {
      // the config branch (json from remote URL)
      // must be a map with the 'name' as its root level key
      return info[name];
    }
    assert(false, 'config branch error: "$name" -> $remote, $info');
    return null;
  }

}


abstract interface class ConfigServer {

  static Future<dynamic> download(String remote) async {
    var url = HtmlUri.parseUri(remote);
    if (url == null) {
      assert(false, 'URL error: $remote');
      return null;
    }
    try {
      //
      //  1. download
      //
      var http = FileDownloader(HTTPClient());
      var data = await http.download(url);
      if (data == null) {
        Log.error('failed to download: $url');
        return null;
      }
      //
      //  2. decode
      //
      var text = UTF8.decode(data);
      if (text == null) {
        assert(false, 'data error: ${data.length} bytes');
        return null;
      }
      var info = JSON.decode(text);
      if (info == null) {
        assert(false, 'json data error: $text');
        return null;
      }
      // OK
      Log.info('downloaded json: $remote -> $text');
      return info;
    } catch (e, st) {
      Log.error('failed to download: $remote, error: $e, $st');
    }
    assert(false, 'failed to download: $remote');
    return null;
  }

}

abstract interface class ConfigStorage {

  static Future<Map?> load(String path) async {
    try {
      if (await Paths.exists(path)) {
        return await ExternalStorage.loadJsonMap(path);
      }
    } catch (e, st) {
      Log.error('failed to load file: $path, error: $e, $st');
    }
    // assert(false, 'local file not exists: $path');
    return null;
  }

  static Future<bool> save(Map info, String path) async {
    try {
      int size = await ExternalStorage.saveJsonMap(info, path);
      if (size > 0) {
        return true;
      }
    } catch (e, st) {
      Log.error('failed to save file: $path, error: $e, $st');
    }
    assert(false, 'failed to save file: $path');
    return false;
  }

}
