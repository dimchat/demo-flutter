import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import 'ftp.dart';
import 'weak.dart';

class ImageViewFactory {
  factory ImageViewFactory() => _instance;
  static final ImageViewFactory _instance = ImageViewFactory._internal();
  ImageViewFactory._internal();

  Widget fromContent(ImageContent content, {GestureTapCallback? onTap}) {
    Image? image = ImageFactory().fromContent(content);
    if (image != null) {
      // local image
      return GestureDetector(
        onTap: onTap,
        child: image,
      );
    }
    String? filename = content.filename;
    String? url = content.url;
    if (filename == null || url == null) {
      return _imageNotFound(content);
    }
    Future.delayed(const Duration(milliseconds: 128)).then((value) =>
        ImageFactory().downloadContent(content).then((image) =>
            NotificationCenter().postNotification('ImageContentRefresh', this, {
              'content': content,
            })
        )
    );
    return _ImageView(content: content, onTap: onTap);
  }

}

/// Auto refresh image view
class _ImageView extends StatefulWidget {
  const _ImageView({required this.content, this.onTap});

  final ImageContent content;
  final GestureTapCallback? onTap;

  @override
  State<StatefulWidget> createState() => _ImageViewState();

}

class _ImageViewState extends State<_ImageView> implements lnc.Observer {
  _ImageViewState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, 'ImageContentRefresh');
  }

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, 'ImageContentRefresh');
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    assert(name == 'ImageContentRefresh', 'should not happen');
    ImageContent? content = userInfo?['content'];
    if (content == widget.content) {
      if (mounted) {
        setState(() {
          // refresh
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Image? image = ImageFactory().fromContent(widget.content);
    if (image == null) {
      return _imageNotFound(widget.content);
    } else {
      return GestureDetector(onTap: widget.onTap, child: image);
    }
  }

}

Widget _imageNotFound(ImageContent content) {
  // check thumbnail
  Uint8List? thumbnail = content.thumbnail;
  if (thumbnail == null) {
    Log.error('image content error: ${content.dictionary}');
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

class ImageFactory {
  factory ImageFactory() => _instance;
  static final ImageFactory _instance = ImageFactory._internal();
  ImageFactory._internal();

  // filename => image
  //     path => image
  //      url => image
  //       ID => image
  final Map<String, Image> _images = WeakValueMap();

  Image? fromID(ID identifier) => _images[identifier.string];

  /// Download avatar from visa document
  Future<Image?> downloadDocument(Document visa) async {
    Image? img = fromDocument(visa);
    if (img != null) {
      return img;
    }
    String? url;
    if (visa is Visa) {
      url = visa.avatar;
    } else {
      url = visa.getProperty('avatar');
    }
    if (url == null) {
      return null;
    }
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } on FormatException catch (e) {
      Log.error('avatar url error: $url, $e');
      return null;
    }
    ID identifier = visa.identifier;
    // get local file path, if not exists
    // try to download from file server
    String? path = await FileTransfer().downloadAvatar(uri);
    if (path == null) {
      Log.error('failed to download avatar: $identifier -> $url');
    } else {
      img = _images[path];
      img ??= Image.file(File(path));
      // cache it
      _images[path] = img;
      _images[url] = img;
      _images[identifier.string] = img;
    }
    return img;
  }

  Image? fromDocument(Document visa) {
    ID identifier = visa.identifier;
    Image? img = _images[identifier.string];
    if (img != null) {
      return img;
    }
    String? url;
    if (visa is Visa) {
      url = visa.avatar;
    } else {
      url = visa.getProperty('avatar');
    }
    if (url != null) {
      img = _images[url];
      if (img != null) {
        // cache it
        _images[identifier.string] = img;
      }
    }
    return img;
  }

  /// Download image from message content
  Future<Image?> downloadContent(ImageContent content) async {
    Image? img = fromContent(content);
    if (img != null) {
      return img;
    }
    String? filename = content.filename;
    String? url = content.url;
    // get local file path, if not exists
    // try to download from file server
    String? path = await FileTransfer().getFilePath(content);
    if (path == null) {
      Log.error('failed to download image: $filename -> $url');
    } else {
      img = _images[path];
      img ??= Image.file(File(path));
      // cache it
      _images[path] = img;
      if (filename != null) {
        _images[filename] = img;
      }
      if (url != null) {
        _images[url] = img;
      }
    }
    return img;
  }

  Image? fromContent(ImageContent content) {
    Image? img;
    // check memory cache
    String? filename = content.filename;
    if (filename != null) {
      img = _images[filename];
      if (img != null) {
        return img;
      }
    }
    String? url = content.url;
    if (url != null) {
      img = _images[url];
      if (img != null) {
        return img;
      }
    }
    // check file data in image content
    Uint8List? data = content.data;
    if (data != null) {
      img = Image.memory(data);
      // cache it
      if (filename != null) {
        _images[filename] = img;
      }
      if (url != null) {
        _images[url] = img;
      }
    }
    return img;
  }

}
