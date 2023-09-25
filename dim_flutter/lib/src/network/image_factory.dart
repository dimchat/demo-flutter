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
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../widgets/browser.dart';
import 'ftp.dart';

class ImageFactory {
  factory ImageFactory() => _instance;
  static final ImageFactory _instance = ImageFactory._internal();
  ImageFactory._internal();

  // filename => imageProvider
  //     path => imageProvider
  //      url => imageProvider
  //       ID => imageProvider
  final Map<String, ImageProvider> _providers = WeakValueMap();

  /// Get avatar
  ImageProvider? fromID(ID identifier) => _providers[identifier.toString()];

  ImageProvider? getImage(String url) => _providers[url];

  static Future<ImageProvider<Object>?> getImageFromFile(String path) async {
    // return FileImage(File(path));
    try {
      File file = File(path);
      if (!await file.exists()) {
        assert(false, 'image file not exists: $path');
        return null;
      }
      int end = await file.length();
      Uint8List bytes = file.readAsBytesSync();
      if (end != bytes.length || end <= 32) {
        Log.error('[IMG] file size error: $end(${bytes.length}');
        file.delete();
        return null;
      }
      end = 32;  // only check the head
      int pos = 0;
      for (; pos < end; ++pos) {
        if (bytes[pos] != 0) {
          break;
        }
      }
      if (pos == end) {
        // data error
        Log.warning('[IMG] image file error, remove it: $path');
        file.delete();
        return null;
      }
      return MemoryImage(bytes);
    } catch (e) {
      Log.error('[IMG] failed to get image from file: $path, error: $e');
      return null;
    }
  }

  /// Download avatar from remote URL
  Future<ImageProvider?> downloadImage(String url) async {
    if (!url.contains('://')) {
      Log.warning('image url error: $url');
      return null;
    }
    // check cache
    ImageProvider? image = _providers[url];
    if (image != null) {
      return image;
    }
    Uri? uri = Browser.parseUri(url);
    if (uri == null) {
      Log.error('image url error: $url');
      return null;
    }
    // get local file path, if not exists
    // try to download from file server
    String? path = await FileTransfer().downloadAvatar(uri);
    if (path == null) {
      Log.error('failed to download image: $url');
      return null;
    } else {
      image = _providers[path];
      if (image == null) {
        image = await getImageFromFile(path);
        if (image == null) {
          Log.error('failed to get image from path: $path');
          return null;
        }
      }
      // cache it
      _providers[path] = image;
      _providers[url] = image;
      return image;
    }
  }

  /// Download avatar from visa document
  Future<ImageProvider?> downloadDocument(Document visa) async {
    ID identifier = visa.identifier;
    // get avatar url from visa
    String? url;
    if (visa is Visa) {
      url = visa.avatar?.toString();
    } else {
      var avatar = PortableNetworkFile.parse(visa.getProperty('avatar'));
      url = avatar?.toString();
    }
    if (url == null) {
      Log.warning('avatar url not found: $identifier, $visa');
      return _providers[identifier.toString()];
    }
    // download image
    ImageProvider? image = await downloadImage(url);
    if (image == null) {
      Log.error('cannot download avatar: $identifier -> $url');
      return _providers[identifier.toString()];
    } else {
      _providers[identifier.toString()] = image;
      return image;
    }
  }

  ImageProvider? fromDocument(Document visa) {
    ID identifier = visa.identifier;
    ImageProvider? image;
    // check avatar url
    String? url;
    if (visa is Visa) {
      url = visa.avatar?.toString();
    } else {
      var avatar = PortableNetworkFile.parse(visa.getProperty('avatar'));
      url = avatar?.toString();
    }
    if (url != null) {
      image = _providers[url];
      if (image != null) {
        // cache it
        _providers[identifier.toString()] = image;
      }
    }
    return image ?? _providers[identifier.toString()];
  }

  /// Download image from message content
  Future<ImageProvider?> downloadContent(ImageContent content) async {
    ImageProvider? image = fromContent(content);
    if (image != null) {
      return image;
    }
    String? filename = content.filename;
    String? url = content.url?.toString();
    // get local file path, if not exists
    // try to download from file server
    String? path = await FileTransfer().getFilePath(content);
    if (path == null) {
      Log.error('failed to download image: $filename -> $url');
    } else {
      image = _providers[path];
      if (image == null) {
        image = await getImageFromFile(path);
        if (image == null) {
          Log.error('failed to get image from path: $path');
          return null;
        }
      }
      // cache it
      _providers[path] = image;
      if (filename != null) {
        _providers[filename] = image;
      }
      if (url != null) {
        _providers[url] = image;
      }
    }
    return image;
  }

  ImageProvider? fromContent(ImageContent content) {
    ImageProvider? image;
    // check memory cache
    String? filename = content.filename;
    if (filename != null) {
      image = _providers[filename];
      if (image != null) {
        return image;
      }
    }
    String? url = content.url?.toString();
    if (url != null) {
      image = _providers[url];
      if (image != null) {
        return image;
      }
    }
    // check file data in image content
    Uint8List? data = content.data;
    if (data != null) {
      image = MemoryImage(data);
      // cache it
      if (filename != null) {
        _providers[filename] = image;
      }
      if (url != null) {
        _providers[url] = image;
      }
    }
    return image;
  }

}
