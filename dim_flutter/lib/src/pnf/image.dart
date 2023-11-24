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
import '../ui/styles.dart';
import '../widgets/circle_progress.dart';

import 'loader.dart';


class PortableImageView extends StatefulWidget {
  const PortableImageView(this.loader, {super.key});

  final PortableImageLoader loader;

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
      if (url == widget.pnf.url || notification.sender == widget.loader) {
        Uint8List? data = userInfo?['data'];
        String? path = userInfo?['path'];
        Log.info('[PNF] onDecrypted: ${data?.length} bytes into file "$path", $url');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkSuccess) {
      if (url == widget.pnf.url || notification.sender == widget.loader) {
        Uint8List? data = userInfo?['data'];
        Log.info('[PNF] onSuccess: ${data?.length} bytes, $url');
        await _reload();
      }
    } else if (name == NotificationNames.kPortableNetworkError) {
      if (url == widget.pnf.url || notification.sender == widget.loader) {
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
    var loader = widget.loader;
    Widget? indicator = loader.getProgress(widget);
    if (indicator == null) {
      return loader.getImage(widget);
    }
    return Stack(
      alignment: AlignmentDirectional.center,
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

  Widget getImage(PortableImageView view);

  Widget? getProgress(PortableImageView view) {
    if (status == PortableNetworkStatus.success) {
      return null;
    } else if (status == PortableNetworkStatus.error) {
      return Text('Error'.tr,
        style: TextStyle(color: Styles.colors.criticalButtonColor,
          fontSize: 12,
          decoration: TextDecoration.none,
        ),
      );
    }
    double len = total.toDouble();
    double value = len > 0 ? count / len : 0.0;
    return CircleProgressWidget.from(value,
      color: Styles.colors.avatarColor,
      backgroundColor: Styles.colors.avatarDefaultColor,
      // textStyle: Styles.buttonTextStyle,
      completeText: 'Decrypting'.tr,
    );

  }

}
