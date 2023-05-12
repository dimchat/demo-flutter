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
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/shared.dart';
import '../views/styles.dart';
import 'image_factory.dart';

class ImageViewFactory {
  factory ImageViewFactory() => _instance;
  static final ImageViewFactory _instance = ImageViewFactory._internal();
  ImageViewFactory._internal();

  /// show Avatar
  Widget fromID(ID identifier,
      {double? width, double? height, GestureTapCallback? onTap}) {
    width ??= 32;
    height ??= 32;
    // 1. create avatar view
    _FacadeView view = _FacadeView(_FacadeInfo(identifier),
        width: width, height: height, onTap: onTap);
    // 2. delay a while to reload document for avatar
    _delay(() => view.reload());
    // 3. return framed view
    return ClipRRect(
      borderRadius: BorderRadius.all(
          Radius.elliptical(width / 8, height / 8)
      ),
      child: view,
    );
  }

  /// show ImageContent
  Widget fromContent(ImageContent content, {GestureTapCallback? onTap}) {
    ImageFactory factory = ImageFactory();
    // 0. check cache
    ImageProvider? image = factory.fromContent(content);
    if (image != null) {
      // local cached image
      if (onTap == null) {
        return Image(image: image);
      }
      return GestureDetector(
        onTap: onTap,
        child: Image(image: image),
      );
    }
    // check content
    String? filename = content.filename;
    String? url = content.url;
    if (filename == null || url == null) {
      return _imageNotFound(content);
    }
    // 1. create image view
    _AutoImageView view = _AutoImageView(content, onTap: onTap);
    // 2. delay a while to refresh image
    _delay(() => view.refresh());
    // 3. OK
    return view;
  }

  static void _delay(void Function() job) =>
      Future.delayed(const Duration(milliseconds: 32)).then((value) => job());

}

const String kFacadeRefresh = 'FacadeRefresh';
const String kImageContentRefresh = 'ImageContentRefresh';

class _FacadeInfo {
  _FacadeInfo(this.identifier);

  final ID identifier;
  Document? visa;
}

/// Auto refresh avatar view
class _FacadeView extends StatefulWidget {
  const _FacadeView(this.info, {this.width = 32, this.height = 32, this.onTap});

  final _FacadeInfo info;
  final double width;
  final double height;
  final GestureTapCallback? onTap;

  /// reload document
  Future<void> reload() async {
    GlobalVariable shared = GlobalVariable();
    Document? doc = await shared.facebook.getDocument(info.identifier, '*');
    if (doc == null) {
      Log.warning('visa document not found: ${info.identifier}');
    } else {
      info.visa = doc;
      await refresh();
    }
  }

  /// refresh avatar
  Future<void> refresh() async {
    Document? doc = info.visa;
    if (doc == null) {
      Log.error('visa document not found: ${info.identifier}');
      return;
    }
    ImageFactory factory = ImageFactory();
    await factory.downloadDocument(doc);
    await lnc.NotificationCenter().postNotification(kFacadeRefresh, this, {
      'ID': info.identifier,
    });
  }

  @override
  State<StatefulWidget> createState() => _FacadeState();

}

class _FacadeState extends State<_FacadeView> implements lnc.Observer {
  _FacadeState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, kFacadeRefresh);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kFileDownloadSuccess);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kFileDownloadSuccess);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    nc.removeObserver(this, kFacadeRefresh);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == kFacadeRefresh) {
      ID? identifier = userInfo?['ID'];
      if (identifier == widget.info.identifier) {
        if (mounted) {
          setState(() {
            // refresh
          });
        }
      }
    } else if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      Document? visa = userInfo?['document'];
      assert(identifier != null && visa != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        Log.info('document updated, refreshing facade: $identifier');
        // update visa document and refresh
        widget.info.visa = visa;
        widget.refresh();
      }
    } else if (name == NotificationNames.kFileDownloadSuccess) {
      Uri? url = userInfo?['url'];
      Document? visa = widget.info.visa;
      String? avatar = visa is Visa ? visa.avatar : visa?.getProperty('avatar');
      if (avatar == null) {
        Log.warning('avatar not found: ${widget.info.identifier}');
      } else if (url?.toString() == avatar) {
        Log.info('avatar downloaded, refreshing facade: $url');
        widget.refresh();
      }
    } else {
      assert(false, 'should not happen');
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageFactory factory = ImageFactory();
    ImageProvider? image;
    // 1. check cache
    Document? visa = widget.info.visa;
    if (visa != null) {
      image = factory.fromDocument(visa);
    }
    // cache not found
    if (image == null) {
      assert(widget.width == widget.height, 'icon size: ${widget.width}*${widget.height}');
      return _avatarNotFound(widget.info.identifier, size: widget.width);
    }
    // 2. create from cache
    Widget view = Image(image: image,
      width: widget.width, height: widget.height,
      fit: BoxFit.cover,
    );
    if (widget.onTap == null) {
      return view;
    } else {
      return GestureDetector(onTap: widget.onTap, child: view);
    }

  }

  static Widget _avatarNotFound(ID identifier, {double? size}) {
    if (identifier.type == EntityType.kStation) {
      return Icon(Styles.stationIcon, size: size);
    } else if (identifier.type == EntityType.kBot) {
      return Icon(Styles.botIcon, size: size);
    } else if (identifier.type == EntityType.kISP) {
      return Icon(Styles.ispIcon, size: size);
    } else if (identifier.type == EntityType.kICP) {
      return Icon(Styles.icpIcon, size: size);
    }
    if (identifier.isUser) {
      return Icon(Styles.userIcon, size: size, color: Styles.avatarDefaultColor);
    } else {
      return Icon(Styles.groupIcon, size: size, color: Styles.avatarDefaultColor);
    }
  }

}

/// Auto refresh image view
class _AutoImageView extends StatefulWidget {
  const _AutoImageView(this.content, {this.onTap});

  final ImageContent content;
  final GestureTapCallback? onTap;

  /// refresh image
  Future<void> refresh() async {
    ImageFactory factory = ImageFactory();
    await factory.downloadContent(content);
    await lnc.NotificationCenter().postNotification(kImageContentRefresh, this, {
      'content': content,
    });
  }

  @override
  State<StatefulWidget> createState() => _AutoImageState();

}

class _AutoImageState extends State<_AutoImageView> implements lnc.Observer {
  _AutoImageState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, kImageContentRefresh);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, kImageContentRefresh);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == kImageContentRefresh) {
      ImageContent? content = userInfo?['content'];
      if (content == widget.content) {
        if (mounted) {
          setState(() {
            // refresh
          });
        }
      }
    } else {
      assert(false, 'should not happen');
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? image = ImageFactory().fromContent(widget.content);
    if (image == null) {
      return _imageNotFound(widget.content);
    } else {
      return GestureDetector(onTap: widget.onTap, child: Image(image: image,));
    }
  }

}

Widget _imageNotFound(ImageContent content) {
  // check thumbnail
  Uint8List? thumbnail = content.thumbnail;
  if (thumbnail == null) {
    Log.error('image content error: $content');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: const Text('Image not found'),
    );
  } else {
    // thumbnail image
    Image image = Image.memory(thumbnail);
    return Container(child: image);
  }
}
