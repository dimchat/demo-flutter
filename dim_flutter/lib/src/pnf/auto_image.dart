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

import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../ui/icons.dart';
import '../ui/styles.dart';

import 'gallery.dart';
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


/// Factory for AutoImage
class NetworkImageFactory {
  factory NetworkImageFactory() => _instance;
  static final NetworkImageFactory _instance = NetworkImageFactory._internal();
  NetworkImageFactory._internal();

  final Map<Uri, PortableImageLoader> _loaders = WeakValueMap();
  final Map<Uri, PortableImageView> _views = WeakValueMap();

  PortableImageLoader getImageLoader(PortableNetworkFile pnf) {
    PortableImageLoader? runner;
    Uri? url = pnf.url;
    if (url == null) {
      runner = _ImageContentLoader(pnf);
      runner.run();
    } else {
      runner = _loaders[url];
      if (runner == null) {
        runner = _ImageContentLoader(pnf);
        _loaders[url] = runner;
        runner.run();
      }
    }
    return runner;
  }

  PortableImageView getImageView(PortableNetworkFile pnf) {
    Uri? url = pnf.url;
    var loader = getImageLoader(pnf);
    if (url == null) {
      return PortableImageView(loader);
    }
    PortableImageView? view = _views[url];
    if (view == null) {
      view = PortableImageView(loader);
      _views[url] = view;
    }
    return view;
  }

}

class _ImageContentLoader extends PortableImageLoader {
  _ImageContentLoader(super.pnf);

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
  Widget getImage(PortableImageView view) {
    var image = imageProvider;
    if (image != null) {
      return Image(image: image,);
    }
    return Icon(AppIcons.noImageIcon,
      color: Styles.colors.avatarDefaultColor,
    );
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
    return Paths.append(dir, 'files');
  }

}
