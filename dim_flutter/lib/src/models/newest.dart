import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:dim_client/ok.dart';

import '../client/client.dart';
import '../client/shared.dart';
import '../common/platform.dart';
import '../ui/styles.dart';
import '../widgets/alert.dart';
import '../widgets/browser.dart';
import '../widgets/gaussian.dart';

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
    clientVersion = clientVersion.substring(0, pos + 1);
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
    clientVersion = clientVersion.substring(0, pos + 1);
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
