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
import 'package:flutter/cupertino.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;

import '../client/shared.dart';
import '../common/constants.dart';
import '../filesys/local.dart';
import '../filesys/upload.dart';
import '../ui/icons.dart';
import '../ui/styles.dart';

import 'gallery.dart';
import 'image.dart';
import 'loader.dart';
import 'net_image.dart';


/// preview avatar image
void previewAvatar(BuildContext context, ID identifier, PortableNetworkFile avatar, {
  BoxFit? fit,
}) {
  var image = AvatarFactory().getImageView(identifier, avatar, fit: fit);
  Gallery([image], 0).show(context);
}


/// Factory for Auto Avatar
class AvatarFactory {
  factory AvatarFactory() => _instance;
  static final AvatarFactory _instance = AvatarFactory._internal();
  AvatarFactory._internal();

  final Map<String, _AvatarImageLoader> _loaders = WeakValueMap();
  final Map<Uri, Set<_AvatarImageView>> _views = {};
  final Map<ID, Set<_AutoAvatarView>> _avatars = {};

  PortableImageLoader getImageLoader(PortableNetworkFile pnf) {
    _AvatarImageLoader? runner;
    var filename = pnf.filename;
    var url = pnf.url;
    if (url != null) {
      runner = _loaders[url.toString()];
      if (runner == null) {
        runner = _createLoader(pnf);
        _loaders[url.toString()] = runner;
      }
    } else if (filename != null) {
      runner = _loaders[filename];
      if (runner == null) {
        runner = _createUpper(pnf);
        _loaders[filename] = runner;
      }
    } else {
      throw FormatException('PNF error: $pnf');
    }
    return runner;
  }

  _AvatarImageLoader _createLoader(PortableNetworkFile pnf) {
    _AvatarImageLoader loader = _AvatarImageLoader(pnf);
    if (pnf.data == null) {
      var ftp = SharedFileUploader();
      loader.prepare().then((value) => ftp.addAvatarTask(loader.downloadTask!));
    }
    return loader;
  }

  _AvatarImageLoader _createUpper(PortableNetworkFile pnf) {
    _AvatarImageLoader loader = _AvatarImageLoader(pnf);
    if (pnf['enigma'] != null) {
      var ftp = SharedFileUploader();
      loader.prepare().then((value) => ftp.addUploadTask(loader.uploadTask!));
    }
    return loader;
  }

  PortableImageView getImageView(ID user, PortableNetworkFile pnf, {
    double? width, double? height, BoxFit? fit,
  }) {
    var loader = getImageLoader(pnf);
    Uri? url = pnf.url;
    if (url == null) {
      return _AvatarImageView(user, loader, width: width, height: height, fit: fit,);
    }
    _AvatarImageView? img;
    Set<_AvatarImageView>? table = _views[url];
    if (table == null) {
      table = WeakSet();
      _views[url] = table;
    } else {
      for (_AvatarImageView item in table) {
        if (item.width != width || item.height != height) {
          // size not match
        } else if (item.identifier != user) {
          // ID not match
        } else {
          // got it
          img = item;
          break;
        }
      }
    }
    if (img == null) {
      img = _AvatarImageView(user, loader, width: width, height: height, fit: fit,);
      table.add(img);
    }
    return img;
  }

  Widget getAvatarView(ID user, {
    double? width, double? height, BoxFit? fit,
  }) {
    width ??= 32;
    height ??= 32;
    _AutoAvatarView? avt;
    Set<_AutoAvatarView>? table = _avatars[user];
    if (table == null) {
      table = WeakSet();
      _avatars[user] = table;
    } else {
      for (_AutoAvatarView item in table) {
        if (item.width != width || item.height != height) {
          // size not match
        } else {
          assert(item.identifier == user, 'should not happen: ${item.identifier}, $user');
          // got it
          avt = item;
          break;
        }
      }
    }
    if (avt == null) {
      avt = _AutoAvatarView(user, width: width, height: height, fit: fit,);
      table.add(avt);
    }
    return avt;
  }

}

class _Info {
  _Info(this.identifier, {required this.width, required this.height, required this.fit});

  final ID identifier;
  final double width;
  final double height;
  final BoxFit? fit;

  PortableNetworkFile? avatar;
  PortableImageView? avatarView;

  static from(ID identifier, {
    required double width, required double height, required BoxFit? fit,
  }) {
    var info = _Info(identifier, width: width, height: height, fit: fit);
    GlobalVariable shared = GlobalVariable();
    shared.facebook.getVisa(identifier).then((visa) {
      var avatar = visa?.avatar;
      if (avatar != null) {
        info.avatar = avatar;
        var factory = AvatarFactory();
        info.avatarView = factory.getImageView(identifier, avatar,
          width: width, height: height, fit: fit);
        var nc = lnc.NotificationCenter();
        nc.postNotification(_kAutoAvatarUpdate, info, {
          'ID': identifier,
        });
      }
    });
    return info;
  }

}

const String _kAutoAvatarUpdate = '_AutoAvatarUpdate';

/// Auto refresh avatar view
class _AutoAvatarView extends StatefulWidget {
  _AutoAvatarView(ID identifier, {
    required double width, required double height, required BoxFit? fit,
  }) : info = _Info.from(identifier, width: width, height: height, fit: fit);

  final _Info info;

  ID get identifier => info.identifier;
  double get width => info.width;
  double get height => info.height;
  BoxFit? get fit => info.fit;

  @override
  State<StatefulWidget> createState() => _AutoAvatarState();

}

class _AutoAvatarState extends State<_AutoAvatarView> implements lnc.Observer {
  _AutoAvatarState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, _kAutoAvatarUpdate);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, _kAutoAvatarUpdate);
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
      if (identifier == widget.identifier && visa is Visa) {
        Log.info('document updated, refreshing avatar: $identifier');
        // update refresh for new avatar
        await _reload();
      }
    } else if (name == _kAutoAvatarUpdate) {
      ID? identifier = userInfo?['ID'];
      if (identifier == widget.identifier) {
        Log.info('avatar updated, refreshing avatar: $identifier');
        // refresh for avatar
        if (mounted) {
          setState(() {
          });
        }
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
    } else if (avatar == widget.info.avatar) {
      Log.warning('avatar not changed: $identifier, $avatar');
      return;
    } else {
      widget.info.avatar = avatar;
    }
    var factory = AvatarFactory();
    widget.info.avatarView = factory.getImageView(identifier, avatar,
        width: widget.width, height: widget.height, fit: widget.fit);
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    ID identifier = widget.identifier;
    Widget? view = widget.info.avatarView;
    view ??= _AvatarImageView.getNoImage(identifier, width: width, height: height);
    return ClipRRect(
      borderRadius: BorderRadius.all(
        Radius.elliptical(width / 8, height / 8),
      ),
      child: view,
    );
  }

}

/// Auto refresh image view
class _AvatarImageView extends PortableImageView {
  const _AvatarImageView(this.identifier, super.loader, {super.width, super.height, super.fit});

  final ID identifier;

  static Widget getNoImage(ID identifier, {double? width, double? height}) {
    double? size = width ?? height;
    if (identifier.type == EntityType.STATION) {
      return Icon(AppIcons.stationIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.BOT) {
      return Icon(AppIcons.botIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.ISP) {
      return Icon(AppIcons.ispIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.ICP) {
      return Icon(AppIcons.icpIcon, size: size, color: Styles.colors.avatarColor);
    }
    if (identifier.isUser) {
      return Icon(AppIcons.userIcon, size: size, color: Styles.colors.avatarDefaultColor);
    } else {
      return Icon(AppIcons.groupIcon, size: size, color: Styles.colors.avatarDefaultColor);
    }
  }

}

class _AvatarImageLoader extends PortableImageLoader {
  _AvatarImageLoader(super.pnf);

  @override
  Widget getImage(PortableImageView widget, {BoxFit? fit}) {
    _AvatarImageView aiv = widget as _AvatarImageView;
    ID identifier = aiv.identifier;
    double? width = widget.width;
    double? height = widget.height;
    var image = imageProvider;
    if (image == null) {
      return _AvatarImageView.getNoImage(identifier, width: width, height: height);
    } else if (width == null && height == null) {
      return ImageUtils.image(image, fit: fit);
    } else {
      return ImageUtils.image(image, width: width, height: height, fit: fit ?? BoxFit.cover,);
    }
  }

  @override
  Future<void> prepare() async {
    if (pnf.url == null) {
      return await super.prepare();
    } else {
      var ftp = SharedFileUploader();
      var task = _AvatarDownloadTask(pnf);
      await ftp.addAvatarTask(task);
      downloadTask = task;
    }
  }

  @override
  Future<String?> get cacheFilePath async => await _getAvatarPath(filename, pnf);

}

class _AvatarDownloadTask extends PortableFileDownloadTask {
  _AvatarDownloadTask(super.pnf);

  @override
  Future<String?> get cacheFilePath async => await _getAvatarPath(filename, pnf);

}

Future<String?> _getAvatarPath(String? filename, PortableNetworkFile pnf) async {
  if (filename == null || filename.isEmpty) {
    assert(false, 'PNF error: $pnf');
    return null;
  }
  LocalStorage cache = LocalStorage();
  return await cache.getAvatarFilePath(filename);
}
