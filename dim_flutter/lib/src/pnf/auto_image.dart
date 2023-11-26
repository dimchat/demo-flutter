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
import 'package:lnc/lnc.dart';

import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../ui/icons.dart';
import '../ui/styles.dart';

import 'gallery.dart';
import 'http.dart';
import 'image.dart';


/// preview image in chat box
void previewImageContent(BuildContext context, ImageContent image, List<InstantMessage> messages) {
  int pos = messages.length;
  Content item;
  PortableNetworkFile? pnf;
  List<PortableImageView> images = [];
  NetworkImageFactory factory = NetworkImageFactory();
  int index = -1;
  while (--pos >= 0) {
    item = messages[pos].content;
    if (item is! ImageContent) {
      // skip other contents
      continue;
    } else if (item == image) {
      assert(index == -1, 'duplicated message?');
      index = images.length;
    }
    pnf = PortableNetworkFile.parse(item);
    if (pnf == null) {
      assert(false, '[PNF] image content error: $item');
      continue;
    }
    images.add(factory.getImageView(pnf));
  }
  assert(images.length > index && index >= 0, 'index error: $index, ${images.length}');
  Gallery(images, index).show(context);
}


void saveImageContent(BuildContext context, ImageContent image) {
  PortableNetworkFile? pnf = PortableNetworkFile.parse(image);
  if (pnf == null) {
    assert(false, 'PNF error: $image');
    return;
  }
  var factory = NetworkImageFactory();
  var loader = factory.getImageLoader(pnf);
  return Gallery.saveImage(context, loader);
}


/// Factory for AutoImage
class NetworkImageFactory {
  factory NetworkImageFactory() => _instance;
  static final NetworkImageFactory _instance = NetworkImageFactory._internal();
  NetworkImageFactory._internal();

  final Map<Uri, _ImageLoader> _loaders = WeakValueMap();
  final Map<Uri, Set<_ImageView>> _views = {};

  PortableImageLoader getImageLoader(PortableNetworkFile pnf) {
    _ImageLoader? runner;
    Uri? url = pnf.url;
    if (url == null) {
      runner = _ImageLoader.from(pnf);
    } else {
      runner = _loaders[url];
      if (runner == null) {
        runner = _ImageLoader.from(pnf);
        _loaders[url] = runner;
      }
    }
    return runner;
  }

  PortableImageView getImageView(PortableNetworkFile pnf, {double? width, double? height}) {
    Uri? url = pnf.url;
    var loader = getImageLoader(pnf);
    if (url == null) {
      return _ImageView(loader, width: width, height: height,);
    }
    _ImageView? img;
    Set<_ImageView>? table = _views[url];
    if (table == null) {
      table = WeakSet();
      _views[url] = table;
    } else {
      for (_ImageView item in table) {
        if (item.width != width || item.height != height) {
          // size not match
        } else {
          // got it
          img = item;
          break;
        }
      }
    }
    if (img == null) {
      img = _ImageView(loader, width: width, height: height,);
      table.add(img);
    }
    return img;
  }

}

class _ImageView extends PortableImageView {
  const _ImageView(super.loader, {super.width, super.height});

  static Widget getNoImage({double? width, double? height}) {
    double? size = width ?? height;
    return Icon(AppIcons.noImageIcon, size: size,
      color: Styles.colors.avatarDefaultColor,
    );
  }

}

class _ImageLoader extends PortableImageLoader {
  _ImageLoader(super.pnf);

  ImageProvider<Object>? _thumbnail;

  @override
  ImageProvider<Object>? get imageProvider {
    var image = super.imageProvider;
    if (image != null) {
      return image;
    }
    // check thumbnail
    image = _thumbnail;
    if (image == null) {
      var base64 = pnf['thumbnail'];
      if (base64 is String) {
        Uint8List? bytes = Base64.decode(base64);
        if (bytes != null && bytes.isNotEmpty) {
          image = _thumbnail = MemoryImage(bytes);
        } else {
          assert(false, 'thumbnail error: $base64');
        }
      }
    }
    return image;
  }

  @override
  Widget getImage(PortableImageView widget) {
    double? width = widget.width;
    double? height = widget.height;
    var image = imageProvider;
    if (image == null) {
      return _ImageView.getNoImage(width: width, height: height);
    } else if (width == null && height == null) {
      return Image(image: image,);
    } else {
      return Image(image: image, width: width, height: height, fit: BoxFit.cover,);
    }
  }

  @override
  Future<String?> get temporaryFilePath async {
    String? download = await super.temporaryFilePath;
    if (download != null && await Paths.exists(download)) {
      return download;
    }
    String? upload = await uploadFilePath;
    Log.debug('download path not exist, checking upload path: $download -> $upload');
    if (upload != null && await Paths.exists(upload)) {
      return upload;
    }
    Log.debug('upload path not exist, use download path: $download');
    return download;
  }

  Future<String?> get uploadFilePath async {
    String? name = temporaryFilename;
    if (name == null || name.isEmpty) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    LocalStorage cache = LocalStorage();
    return await cache.getUploadFilePath(name);
  }

  //
  //  Factory
  //
  static _ImageLoader from(PortableNetworkFile pnf) {
    _ImageLoader loader = _ImageLoader(pnf);
    if (pnf.url != null && pnf.data == null) {
      SharedDownloader().addTask(loader);
    }
    return loader;
  }

}
