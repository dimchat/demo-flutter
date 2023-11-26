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
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../common/constants.dart';
import '../ui/icons.dart';

import 'loader.dart';


class PortableImageView extends StatefulWidget {
  const PortableImageView(this.loader, {this.width, this.height, super.key});

  final PortableImageLoader loader;

  final double? width;
  final double? height;

  PortableNetworkFile get pnf => loader.pnf;

  @override
  State<StatefulWidget> createState() => _PortableImageState();

}

class _PortableImageState extends State<PortableImageView> implements lnc.Observer {
  _PortableImageState() {
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
      if (url == widget.pnf.url || notification.sender == widget.loader) {
        var previous = userInfo?['previous'];
        var current = userInfo?['current'];
        Log.info('[PNF] onStatusChanged: $previous -> $current, $url, $this');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkReceiveProgress) {
      if (url == widget.pnf.url) {
        // Log.info('[PNF] onReceiveProgress: $count/$total, ${pnf.url}, $this');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkReceived) {
      if (url == widget.pnf.url) {
        Uint8List? data = userInfo?['data'];
        String? tmpPath = userInfo?['path'];
        Log.info('[PNF] onReceived: ${data?.length} bytes into file "$tmpPath", $this');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkDecrypted) {
      if (url == widget.pnf.url || notification.sender == widget.loader) {
        Uint8List? data = userInfo?['data'];
        String? path = userInfo?['path'];
        Log.info('[PNF] onDecrypted: ${data?.length} bytes into file "$path", $url, $this');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkSuccess) {
      if (url == widget.pnf.url || notification.sender == widget.loader) {
        Uint8List? data = userInfo?['data'];
        Log.info('[PNF] onSuccess: ${data?.length} bytes, $url, $this');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkError) {
      if (url == widget.pnf.url || notification.sender == widget.loader) {
        String? error = userInfo?['error'];
        Log.error('[PNF] onError: $error, $url, $this');
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
    var loader = widget.loader;
    Widget? indicator = loader.getProgress(widget);
    if (indicator == null) {
      return loader.getImage(widget);
    }
    return Stack(
      alignment: AlignmentDirectional.center,
      // fit: StackFit.passthrough,
      children: [
        loader.getImage(widget),
        indicator,
      ],
    );
  }

}


abstract class PortableImageLoader extends PortableNetworkLoader {
  PortableImageLoader(super.pnf);

  ImageProvider<Object>? _provider;

  ImageProvider<Object>? get imageProvider {
    var image = _provider;
    if (image == null) {
      // check file content
      Uint8List? bytes = content;
      if (bytes != null && bytes.isNotEmpty) {
        image = _provider = MemoryImage(bytes);
      // } else {
      //   // waiting to download & decrypt
      }
    }
    return image;
  }

  Widget getImage(PortableImageView widget);

  Widget? getProgress(PortableImageView widget) {
    PortableNetworkStatus pns = status;
    if (pns == PortableNetworkStatus.success ||
        pns == PortableNetworkStatus.init) {
      return null;
    }
    String text;
    IconData? icon;
    Color color = CupertinoColors.white;
    // check status
    if (pns == PortableNetworkStatus.error) {
      text = 'Error';
      icon = AppIcons.decryptErrorIcon;
      color = CupertinoColors.systemRed;
    } else if (pns == PortableNetworkStatus.downloading) {
      double len = total.toDouble();
      double value = len > 0 ? count * 100.0 / len : 0.0;
      if (value < 100.0) {
        text = '${value.toStringAsFixed(1)}%';
      } else {
        text = 'Decrypting';
        icon = AppIcons.decryptingIcon;
      }
    } else if (pns == PortableNetworkStatus.decrypting) {
      text = 'Decrypting';
      icon = AppIcons.decryptingIcon;
    } else if (pns == PortableNetworkStatus.waiting) {
      text = 'Waiting';
    } else {
      assert(false, 'status error: $pns');
      return null;
    }
    // check size
    double? width = widget.width;
    double? height = widget.height;
    if (width == null || height == null) {
      // size unlimited
    } else if (width < 64 || height < 64) {
      double size = width < height ? width : height;
      return _indicator(icon, color, size);
    }
    // indicator on tray
    return _tray(text, icon, color);
  }

  Widget _indicator(IconData? icon, Color color, double size) => Container(
    color: CupertinoColors.secondaryLabel,
    width: size,
    height: size,
    child: icon == null
        ? CupertinoActivityIndicator(color: color, radius: size/2,)
        : Icon(icon, color: color, size: size,),
  );

  Widget _tray(String text, IconData? icon, Color color) => ClipRRect(
    borderRadius: const BorderRadius.all(
      Radius.elliptical(8, 8),
    ),
    child: Container(
      color: CupertinoColors.secondaryLabel,
      width: 64,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon == null
              ? CupertinoActivityIndicator(color: color)
              : Icon(icon, color: color),
          Text(text,
            style: TextStyle(color: color, fontSize: 10,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    ),
  );

}
