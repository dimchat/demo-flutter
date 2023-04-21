/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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
import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/shared.dart';

/// ImageView
class Facade extends StatefulWidget {
  const Facade(FacadeProvider provider, {super.key})
      : _provider = provider;

  final FacadeProvider _provider;

  static Facade fromID(ID identifier, {double? width, double? height}) {
    return Facade(_AvatarProvider(identifier, width ?? 36, height ?? 36));
  }

  @override
  State<StatefulWidget> createState() => _FacadeState();

}

abstract class FacadeProvider {

  Uri? get url;
  Widget get image;

  Future<bool> reload();

}

class _FacadeState extends State<Facade> implements lnc.Observer {
  _FacadeState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kFileDownloadSuccess);
  }

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kFileDownloadSuccess);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    FacadeProvider provider = widget._provider;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      assert(identifier != null, 'notification error: $notification');
      if (provider is _AvatarProvider && identifier == provider.identifier) {
        Log.info('document updated, refreshing facade: $identifier');
        _resetImage(provider);
      }
    } else if (name == NotificationNames.kFileDownloadSuccess) {
      Uri? url = userInfo?['url'];
      if (url == provider.url) {
        Log.info('file downloaded, refreshing facade: $url');
        _resetImage(provider);
      }
    } else {
      Log.error('notification error: $notification');
    }
  }

  late Widget _image;

  void _resetImage(FacadeProvider provider) {
    setState(() {
      _image = provider.image;
    });
  }

  @override
  void initState() {
    super.initState();
    // init image
    FacadeProvider provider = widget._provider;
    _image = provider.image;
    // reload image
    provider.reload().then((ok) {
      if (ok) {
        Log.warning('Facade reloaded: $provider');
        _resetImage(provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) => _image;

}

class _AvatarProvider implements FacadeProvider {
  _AvatarProvider(this.identifier, this.width, this.height);

  final ID identifier;
  final double width;
  final double height;
  String? _path;

  Uri? _url;
  Widget? _image;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz id="$identifier" width=$width height=$height path="$_path" url=$_url />';
  }

  @override
  Uri? get url => _url;

  @override
  Widget get image {
    Widget? img = _image;
    if (img == null) {
      String? path = _path;
      if (path != null) {
        img = Image.file(File(path), width: width, height: height);
      } else if (identifier.isUser) {
        img = Icon(CupertinoIcons.profile_circled, size: width,);
      } else {
        img = Icon(CupertinoIcons.group, size: width,);
      }
      _image = img;
    }
    return img;
  }

  @override
  Future<bool> reload() async {
    if (identifier.isGroup) {
      // TODO: build group icon
      return false;
    }
    GlobalVariable shared = GlobalVariable();
    Pair<String?, Uri?> pair = await shared.facebook.getAvatar(identifier);
    String? path = pair.first;
    Uri? url = pair.second;
    if (url == null) {
      return false;
    } else if (url != _url) {
      _url = url;
      _image = null;
    }
    if (path == null) {
      return false;
    } else if (path != _path) {
      _path = path;
      _image = null;
    }
    return true;
  }

}
