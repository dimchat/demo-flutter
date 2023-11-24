/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/shared.dart';
import '../common/constants.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../ui/icons.dart';
import '../ui/styles.dart';

import 'loader.dart';


// class AvatarFactory {
//   factory AvatarFactory() => _instance;
//   static final AvatarFactory _instance = AvatarFactory._internal();
//   AvatarFactory._internal();
//
//   Widget getAvatarView(ID identifier, {double? width, double? height, GestureTapCallback? onTap}) {
//     width ??= 32;
//     height ??= 32;
//     Widget view = ClipRRect(
//       borderRadius: BorderRadius.all(
//         Radius.elliptical(width / 8, height / 8),
//       ),
//       child: _AutoAvatarView(identifier, width: width, height: height,),
//     );
//     if (onTap == null) {
//       return view;
//     }
//     return GestureDetector(
//       onTap: onTap,
//       child: view,
//     );
//   }
//
//   static PortableNetworkLoader getLoader(PortableNetworkFile pnf, {PortableNetworkCallback? callback}) =>
//       _PortableNetworkFactory().get(pnf, callback);
//
// }

class _AutoInfo {

  PortableNetworkFile? pnf;
  _PortableAvatarLoader? loader;

}

class _AutoAvatarView extends StatefulWidget {
  _AutoAvatarView(this.identifier, {required this.width, required this.height});

  final ID identifier;
  final double width;
  final double height;

  final _AutoInfo _info = _AutoInfo();

  void setNeedsReload() {
    _info.pnf = null;
    _info.loader = null;
  }

  @override
  State<StatefulWidget> createState() => _AutoImageState();

}

class _AutoImageState extends State<_AutoAvatarView> implements lnc.Observer {
  _AutoImageState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      Document? visa = userInfo?['document'];
      assert(identifier != null && visa != null, 'notification error: $notification');
      if (identifier == widget.identifier) {
        Log.info('document updated, refreshing facade: $identifier');
        // update visa document and refresh
        widget.setNeedsReload();
        await _reload();
      }
    } else {
      assert(false, 'should not happen');
    }
  }

  Future<void> _reload() async {
    ID identifier = widget.identifier;
    GlobalVariable shared = GlobalVariable();
    Visa? doc = await shared.facebook.getVisa(identifier);
    if (doc == null) {
      Log.warning('visa document not found: $identifier');
      return;
    }
    // get visa.avatar
    PortableNetworkFile? avatar = doc.avatar;
    if (avatar == null) {
      Log.warning('avatar not found: $doc');
      return;
    }
    var loader = _PortableNetworkFactory().get(avatar);
    widget._info.pnf = avatar;
    widget._info.loader = loader;
    await loader.run();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    var loader = widget._info.loader;
    ImageProvider? image = loader?.image;
    if (image == null) {
      return getNoImage(width: width, height: height);
    } else {
      return Image(image: image, width: width, height: height, fit: BoxFit.cover,);
    }
  }

  Widget getNoImage({double? width, double? height}) {
    ID identifier = widget.identifier;
    double? size = width ?? height;
    if (identifier.type == EntityType.kStation) {
      return Icon(AppIcons.stationIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.kBot) {
      return Icon(AppIcons.botIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.kISP) {
      return Icon(AppIcons.ispIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.kICP) {
      return Icon(AppIcons.icpIcon, size: size, color: Styles.colors.avatarColor);
    }
    if (identifier.isUser) {
      return Icon(AppIcons.userIcon, size: size, color: Styles.colors.avatarDefaultColor);
    } else {
      return Icon(AppIcons.groupIcon, size: size, color: Styles.colors.avatarDefaultColor);
    }
  }

  @override
  void onDecrypted(Uint8List data, String path, PortableNetworkFile pnf) {
    Log.info('[PNF] onDecrypted: ${data.length} bytes into file "$path", ${pnf.url}');
  }

  @override
  void onError(String error, PortableNetworkFile pnf) {
    Log.error('[PNF] onError: $error, ${pnf.url}');
  }

  @override
  void onReceiveProgress(int count, int total, PortableNetworkFile pnf) {
    Log.info('[PNF] onReceiveProgress: $count/$total, ${pnf.url}');
  }

  @override
  void onReceived(Uint8List data, String tmp, PortableNetworkFile pnf) {
    Log.info('[PNF] onReceived: ${data.length} bytes into file "$tmp"');
  }

  @override
  void onStatusChanged(PortableNetworkStatus previous, PortableNetworkStatus current, PortableNetworkFile pnf) {
    Log.info('[PNF] onStatusChanged: $previous -> $current, ${pnf.url}');
  }

  @override
  void onSuccess(Uint8List data, PortableNetworkFile pnf) {
    Log.info('[PNF] onSuccess: ${data.length} bytes, ${pnf.url}');
    if (mounted) {
      setState(() {
      });
    }
  }

}


class _PortableAvatarLoader extends PortableNetworkLoader {
  _PortableAvatarLoader(super.pnf);

  ImageProvider<Object>? _provider;

  ImageProvider<Object>? get image {
    ImageProvider<Object>? ip = _provider;
    if (ip != null) {
      return ip;
    }
    Uint8List? bytes = content;
    if (bytes == null || bytes.isEmpty) {
      // waiting to download & decrypt
    } else {
      ip = _provider = MemoryImage(bytes);
    }
    return ip;
  }

  @override
  Future<String?> get temporaryDirectory async {
    LocalStorage cache = LocalStorage();
    String? dir = await cache.temporaryDirectory;
    if (dir == null) {
      return null;
    }
    return Paths.append(dir, 'download');
  }

  @override
  Future<String?> get cachesDirectory async {
    LocalStorage cache = LocalStorage();
    String? dir = await cache.cachesDirectory;
    if (dir == null) {
      return null;
    }
    return Paths.append(dir, 'avatar');
  }

}

class _PortableNetworkFactory {
  factory _PortableNetworkFactory() => _instance;
  static final _PortableNetworkFactory _instance = _PortableNetworkFactory._internal();
  _PortableNetworkFactory._internal();

  final Map<Uri, _PortableAvatarLoader> _loaders = WeakValueMap();

  _PortableAvatarLoader get(PortableNetworkFile pnf) {
    _PortableAvatarLoader? runner;
    Uri? url = pnf.url;
    if (url == null) {
      runner = _PortableAvatarLoader(pnf);
      runner.run();
    } else {
      runner = _loaders[url];
      if (runner == null) {
        runner = _PortableAvatarLoader(pnf);
        _loaders[url] = runner;
        runner.run();
      }
    }
    return runner;
  }

}
