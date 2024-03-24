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

import 'package:dim_client/dim_client.dart';

import '../filesys/upload.dart';
import '../ui/icons.dart';
import '../ui/styles.dart';

import 'gallery.dart';
import 'image.dart';
import 'net_image.dart';


/// preview image(s) from conversation
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


/// Save image from content
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


/// Factory for Auto Image
class NetworkImageFactory {
  factory NetworkImageFactory() => _instance;
  static final NetworkImageFactory _instance = NetworkImageFactory._internal();
  NetworkImageFactory._internal();

  final Map<Uri, _ImageLoader> _loaders = WeakValueMap();
  final Map<Uri, Set<_AutoImageView>> _views = {};

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
      return _AutoImageView(loader, width: width, height: height,);
    }
    _AutoImageView? img;
    Set<_AutoImageView>? table = _views[url];
    if (table == null) {
      table = WeakSet();
      _views[url] = table;
    } else {
      for (_AutoImageView item in table) {
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
      img = _AutoImageView(loader, width: width, height: height,);
      table.add(img);
    }
    return img;
  }

}

/// Auto refresh image view
class _AutoImageView extends PortableImageView {
  const _AutoImageView(super.loader, {super.width, super.height});

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
    image ??= _thumbnail = Gallery.getThumbnailProvider(pnf);
    return image;
  }

  @override
  Widget getImage(PortableImageView widget) {
    double? width = widget.width;
    double? height = widget.height;
    var image = imageProvider;
    if (image == null) {
      return _AutoImageView.getNoImage(width: width, height: height);
    } else if (width == null && height == null) {
      return ImageUtils.image(image,);
    } else {
      return ImageUtils.image(image, width: width, height: height, fit: BoxFit.cover,);
    }
  }

  //
  //  Factory
  //
  static _ImageLoader from(PortableNetworkFile pnf) {
    _ImageLoader loader = _ImageLoader(pnf);
    if (pnf.url != null && pnf.data == null) {
      FileUploader().addDownloadTask(loader);
    }
    return loader;
  }

}
