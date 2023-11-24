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
import 'package:get/get.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../common/constants.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../ui/icons.dart';
import '../ui/styles.dart';
import '../widgets/circle_progress.dart';

import 'loader.dart';


class NetworkImageFactory {
  factory NetworkImageFactory() => _instance;
  static final NetworkImageFactory _instance = NetworkImageFactory._internal();
  NetworkImageFactory._internal();

  final Map<Uri, _PortableImageLoader> _loaders = WeakValueMap();
  final Map<Uri, _AutoImageView> _views = WeakValueMap();

  PortableNetworkLoader getImageLoader(PortableNetworkFile pnf) {
    _PortableImageLoader? runner;
    Uri? url = pnf.url;
    if (url == null) {
      runner = _PortableImageLoader(pnf);
      runner.run();
    } else {
      runner = _loaders[url];
      if (runner == null) {
        runner = _PortableImageLoader(pnf);
        _loaders[url] = runner;
        runner.run();
      }
    }
    return runner;
  }

  Widget getImageView(PortableNetworkFile pnf) {
    Uri? url = pnf.url;
    var loader = getImageLoader(pnf) as _PortableImageLoader;
    if (url == null) {
      return _AutoImageView(loader);
    }
    _AutoImageView? view = _views[url];
    if (view == null) {
      view = _AutoImageView(loader);
      _views[url] = view;
    }
    return view;
  }

}

class _AutoImageView extends StatefulWidget {
  const _AutoImageView(this._loader);

  final _PortableImageLoader _loader;

  PortableNetworkFile get pnf => _loader.pnf;

  @override
  State<StatefulWidget> createState() => _AutoImageState();

}

class _AutoImageState extends State<_AutoImageView> implements lnc.Observer {
  _AutoImageState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceiveProgress);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceived);
    nc.addObserver(this, NotificationNames.kPortableNetworkDecrypted);
    nc.addObserver(this, NotificationNames.kPortableNetworkSuccess);
    nc.addObserver(this, NotificationNames.kPortableNetworkError);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kPortableNetworkError);
    nc.removeObserver(this, NotificationNames.kPortableNetworkSuccess);
    nc.removeObserver(this, NotificationNames.kPortableNetworkDecrypted);
    nc.removeObserver(this, NotificationNames.kPortableNetworkReceived);
    nc.removeObserver(this, NotificationNames.kPortableNetworkReceiveProgress);
    nc.removeObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    Uri? url = userInfo?['URL'];
    if (name == NotificationNames.kPortableNetworkStatusChanged) {
      if (url == widget.pnf.url || notification.sender == widget._loader) {
        var previous = userInfo?['previous'];
        var current = userInfo?['current'];
        Log.info('[PNF] onStatusChanged: $previous -> $current, $url');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkReceiveProgress) {
      if (url == widget.pnf.url) {
        // Log.info('[PNF] onReceiveProgress: $count/$total, ${pnf.url}');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkReceived) {
      if (url == widget.pnf.url) {
        Uint8List? data = userInfo?['data'];
        String? tmpPath = userInfo?['path'];
        Log.info('[PNF] onReceived: ${data?.length} bytes into file "$tmpPath"');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkDecrypted) {
      if (url == widget.pnf.url || notification.sender == widget._loader) {
        Uint8List? data = userInfo?['data'];
        String? path = userInfo?['path'];
        Log.info('[PNF] onDecrypted: ${data?.length} bytes into file "$path", $url');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkSuccess) {
      if (url == widget.pnf.url || notification.sender == widget._loader) {
        Uint8List? data = userInfo?['data'];
        Log.info('[PNF] onSuccess: ${data?.length} bytes, $url');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkError) {
      if (url == widget.pnf.url || notification.sender == widget._loader) {
        String? error = userInfo?['error'];
        Log.error('[PNF] onError: $error, $url');
        await _reload();
      }
    }
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget view;
    var loader = widget._loader;
    ImageProvider? image = loader.image;
    if (image == null) {
      view = Icon(AppIcons.noImageIcon,
        color: Styles.colors.avatarDefaultColor,
      );
    } else {
      view = Image(image: image,);
    }
    Widget? indicator;
    PortableNetworkStatus? status = loader.status;
    if (status == PortableNetworkStatus.init) {
      indicator = _progress();
    } else if (status == PortableNetworkStatus.downloading) {
      indicator = _progress();
    } else if (status == PortableNetworkStatus.decrypting) {
      indicator = _progress();
    } else if (status == PortableNetworkStatus.error) {
      indicator = Text('Error'.tr,
        style: TextStyle(color: Styles.colors.criticalButtonColor,
          fontSize: 12,
          decoration: TextDecoration.none,
        ),
      );
    }
    if (indicator == null) {
      return view;
    }
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        view,
        indicator,
      ],
    );
  }

  Widget _progress() {
    int count = widget._loader.count;
    int total = widget._loader.total;
    double value = total > 0 ? count.toDouble() / total.toDouble() : 0.0;
    return CircleProgressWidget.from(value,
      color: Styles.colors.avatarColor,
      backgroundColor: Styles.colors.avatarDefaultColor,
      // textStyle: Styles.buttonTextStyle,
      completeText: 'Decrypting'.tr,
    );
  }

}


class _PortableImageLoader extends PortableNetworkLoader {
  _PortableImageLoader(super.pnf);

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
