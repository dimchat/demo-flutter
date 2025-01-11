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

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:pnf/pnf.dart' show PortableNetworkLoader;

import '../common/constants.dart';
import '../filesys/upload.dart';

import 'loader.dart';


/// Factory for PortableNetworkFile Loader
class PortableNetworkFactory {
  factory PortableNetworkFactory() => _instance;
  static final PortableNetworkFactory _instance = PortableNetworkFactory._internal();
  PortableNetworkFactory._internal();

  final Map<Uri, PortableNetworkLoader> _loaders = WeakValueMap();

  PortableNetworkLoader getLoader(PortableNetworkFile pnf) {
    PortableNetworkLoader? runner;
    Uri? url = pnf.url;
    if (url == null) {
      runner = _createLoader(pnf);
    } else {
      runner = _loaders[url];
      if (runner == null) {
        runner = _createLoader(pnf);
        _loaders[url] = runner;
      }
    }
    return runner;
  }

  PortableNetworkLoader _createLoader(PortableNetworkFile pnf) {
    PortableNetworkLoader loader = PortableFileLoader(pnf);
    if (pnf.url != null && pnf.data == null) {
      SharedFileUploader().addDownloadTask(loader);
    }
    return loader;
  }

}


/// View to show PortableNetworkFile
abstract class PortableNetworkView extends StatefulWidget {
  const PortableNetworkView(this.loader, {super.key});

  final PortableNetworkLoader loader;

  PortableNetworkFile get pnf => loader.pnf;

}

/// View State for PortableNetworkFile
abstract class PortableNetworkState<T extends PortableNetworkView> extends State<T> implements lnc.Observer {
  PortableNetworkState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceiveProgress);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceived);
    nc.addObserver(this, NotificationNames.kPortableNetworkDecrypted);
    nc.addObserver(this, NotificationNames.kPortableNetworkDownloadSuccess);
    nc.addObserver(this, NotificationNames.kPortableNetworkError);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kPortableNetworkError);
    nc.removeObserver(this, NotificationNames.kPortableNetworkDownloadSuccess);
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
    } else if (name == NotificationNames.kPortableNetworkDownloadSuccess) {
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

}
