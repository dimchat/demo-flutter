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

import 'loader.dart';


class _AutoInfo {

  _PortableImageLoader? loader;

}

class AutoImageView extends StatefulWidget {
  AutoImageView({super.key, required this.pnf});

  final PortableNetworkFile pnf;

  final _AutoInfo _info = _AutoInfo();

  @override
  State<StatefulWidget> createState() => _AutoImageState();

  static AutoImageView from(PortableNetworkFile pnf) =>
      AutoImageView(pnf: pnf);

  static AutoImageView fromContent(ImageContent content) =>
      AutoImageView(pnf: PortableNetworkFile.parse(content)!);

  static PortableNetworkLoader getLoader(PortableNetworkFile pnf, {PortableNetworkCallback? callback}) =>
      _PortableNetworkFactory().get(pnf, callback);

}

class _AutoImageState extends State<AutoImageView> implements PortableNetworkCallback {

  @override
  void initState() {
    super.initState();
    widget._info.loader = _PortableNetworkFactory().get(widget.pnf, this);
  }

  @override
  Widget build(BuildContext context) {
    var loader = widget._info.loader;
    ImageProvider? image = loader?.image;
    if (image == null) {
      return Icon(AppIcons.noImageIcon,
        color: Styles.colors.avatarDefaultColor,
      );
    } else {
      return Image(image: image,);
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


class _PortableImageLoader extends PortableNetworkLoader {
  _PortableImageLoader(super.pnf, super.callback);

  ImageProvider<Object>? _provider;
  ImageProvider<Object>? _thumbnail;

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
      return ip;
    }
    // check thumbnail
    ip = _thumbnail;
    if (ip != null) {
      return ip;
    }
    var base64 = pnf['thumbnail'];
    if (base64 is String) {
      bytes = Base64.decode(base64);
      if (bytes == null || bytes.isEmpty) {
        assert(false, 'thumbnail error: $base64');
      } else {
        ip = _thumbnail = MemoryImage(bytes);
      }
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
    return Paths.append(dir, 'files');
  }

}

class _PortableNetworkFactory {
  factory _PortableNetworkFactory() => _instance;
  static final _PortableNetworkFactory _instance = _PortableNetworkFactory._internal();
  _PortableNetworkFactory._internal();

  final Map<Uri, _PortableImageLoader> _loaders = WeakValueMap();

  _PortableImageLoader get(PortableNetworkFile pnf, PortableNetworkCallback? callback) {
    _PortableImageLoader? runner;
    Uri? url = pnf.url;
    if (url == null) {
      runner = _PortableImageLoader(pnf, callback);
      runner.run();
    } else {
      runner = _loaders[url];
      if (runner == null) {
        runner = _PortableImageLoader(pnf, callback);
        _loaders[url] = runner;
        runner.run();
      }
    }
    return runner;
  }

}
