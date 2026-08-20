import 'package:flutter/services.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:pnf/dos.dart';

import '../filesys/local.dart';
import 'config_branch.dart';


class ConfigLoader with Logging {

  Future<void> _updateList(Map config, String name) async {
    var value = await ConfigBranch(config).fetchBranch(name);
    if (value != null) {
      assert(value is List, 'config branch error: "$name" -> $value');
      config[name] = value;
    }
  }
  Future<void> _updateMap(Map config, String name) async {
    var value = await ConfigBranch(config).fetchBranch(name);
    if (value != null) {
      assert(value is Map, 'config branch error: "$name" -> $value');
      config[name] = value;
    }
  }
  Future<Map> _updateBranches(Map config) async {
    try {
      await _updateList(config, 'services');
      await _updateList(config, 'stations');
      await _updateList(config, 'uploads');
      await _updateMap(config, 'newest');
    } catch (e, st) {
      logError('failed to update config branches: $e, $st');
    }
    return config;
  }

  Future<Map> loadAssetsFile(String assets) async {
    logInfo('loading config: $assets');
    try {
      String json = await rootBundle.loadString(assets, cache: false);
      var config = JSONMap.decode(json);
      if (config == null) {
        assert(false, 'config assets error: $assets -> $json');
      } else {
        // await _updateBranches(config);
        return config;
      }
    } catch (e, st) {
      logError('failed to load config from assets: $assets, error: $e, $st');
    }
    // error
    return {};
  }

  Future<String> _cachePath() async {
    String dir = await LocalStorage().cachesDirectory;
    return Paths.append(dir, 'config.json');
  }

  Future<Map?> loadConfig() async {
    String path = await _cachePath();
    logInfo('loading config: $path');
    Map? config = await ConfigStorage.load(path);
    if (config != null) {
      // await _updateBranches(config);
      return config;
    }
    // assert(false, 'failed to load config: $path');
    return null;
  }

  Future<bool> saveConfig(Map cnf) async {
    String path = await _cachePath();
    logWarning('saving config: $path');
    bool ok = await ConfigStorage.save(cnf, path);
    if (ok) {
      return true;
    }
    assert(false, 'failed to save config: $path');
    return false;
  }

  Future<Map?> downloadConfig(String entrance) async {
    logInfo('downloading config: $entrance');
    var config = await ConfigServer.download(entrance);
    if (config is Map) {
      logWarning('downloaded config from: $entrance => $config');
      return await _updateBranches(config);
    }
    logError('failed to download config: $entrance');
    return null;
  }

}
