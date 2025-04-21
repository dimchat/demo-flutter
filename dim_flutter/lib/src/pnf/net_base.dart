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

import '../common/constants.dart';
import '../filesys/upload.dart';

import 'loader.dart';


/// Factory for PortableNetworkFile Loader
class PortableNetworkFactory {
  factory PortableNetworkFactory() => _instance;
  static final PortableNetworkFactory _instance = PortableNetworkFactory._internal();
  PortableNetworkFactory._internal();

  final Map<String, PortableFileLoader> _loaders = WeakValueMap();

  PortableFileLoader getLoader(PortableNetworkFile pnf) {
    PortableFileLoader? runner;
    var filename = pnf.filename;
    var url = pnf.url;
    if (url != null) {
      runner = _loaders[url.toString()];
      if (runner == null) {
        runner = _createLoader(pnf);
        _loaders[url.toString()] = runner;
      }
    } else if (filename != null) {
      runner = _loaders[filename];
      if (runner == null) {
        runner = _createUpper(pnf);
        _loaders[filename] = runner;
      }
    } else {
      throw FormatException('PNF error: $pnf');
    }
    return runner;
  }

  PortableFileLoader _createLoader(PortableNetworkFile pnf) {
    PortableFileLoader loader = PortableFileLoader(pnf);
    if (pnf.data == null) {
      var ftp = SharedFileUploader();
      loader.prepare().then((value) => ftp.addDownloadTask(loader.downloadTask!));
    }
    return loader;
  }

  PortableFileLoader _createUpper(PortableNetworkFile pnf) {
    PortableFileLoader loader = PortableFileLoader(pnf);
    if (pnf['enigma'] != null) {
      var ftp = SharedFileUploader();
      loader.prepare().then((value) => ftp.addUploadTask(loader.uploadTask!));
    }
    return loader;
  }

}


/// View to show PortableNetworkFile
abstract class PortableNetworkView<T> extends StatefulWidget {
  const PortableNetworkView(this.loader, {super.key});

  final PortableFileLoader loader;

  PortableNetworkFile? get pnf {
    var task = loader.downloadTask;
    if (task != null) {
      return task.pnf;
    } else {
      return loader.uploadTask?.pnf;
    }
  }

}

/// View State for PortableNetworkFile
abstract class PortableNetworkState<T extends PortableNetworkView>
    extends State<T> with Logging implements lnc.Observer {
  PortableNetworkState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    nc.addObserver(this, NotificationNames.kPortableNetworkEncrypted);
    nc.addObserver(this, NotificationNames.kPortableNetworkSendProgress);
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
    nc.removeObserver(this, NotificationNames.kPortableNetworkSendProgress);
    nc.removeObserver(this, NotificationNames.kPortableNetworkEncrypted);
    nc.removeObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    PortableNetworkFile? pnf = userInfo?['PNF'];
    String? filename = pnf?.filename;
    Uri? url = userInfo?['URL'];
    // checking
    bool isMatched = false;
    if (notification.sender == widget.loader) {
      isMatched = true;
    } else if (pnf?['sn'] == widget.pnf?['sn']) {
      isMatched = true;
    } else if (url != null) {
      isMatched = url == widget.pnf?.url;
    } else {
      var filename1 = pnf?.filename;
      var filename2 = widget.pnf?.filename;
      isMatched = filename1 == filename2;
    }
    if (!isMatched) {
      // not for this view
      return;
    } else if (name == NotificationNames.kPortableNetworkStatusChanged) {
      var previous = userInfo?['previous'];
      var current = userInfo?['current'];
      logDebug('[PNF] onStatusChanged: $previous -> $current, $url');
    } else if (name == NotificationNames.kPortableNetworkEncrypted) {
      // waiting to send
      Uint8List? data = userInfo?['data'];
      String? path = userInfo?['path'];
      logInfo('[PNF] onEncrypted: ${data?.length} bytes into file "$path", $url');
    } else if (name == NotificationNames.kPortableNetworkSendProgress) {
      // uploading file data
      int? count = userInfo?['count'];
      int? total = userInfo?['total'];
      logInfo('[PNF] onSendProgress: $count/$total, $filename');
    } else if (name == NotificationNames.kPortableNetworkUploadSuccess) {
      Uint8List? data = userInfo?['data'];
      logInfo('[PNF] onSuccess: ${data?.length} bytes, $url');
    } else if (name == NotificationNames.kPortableNetworkReceiveProgress) {
      // downloading file data
      int? count = userInfo?['count'];
      int? total = userInfo?['total'];
      logInfo('[PNF] onReceiveProgress: $count/$total, ${pnf?.url}');
    } else if (name == NotificationNames.kPortableNetworkReceived) {
      // download finished, decrypting
      Uint8List? data = userInfo?['data'];
      String? tmpPath = userInfo?['path'];
      logInfo('[PNF] onReceived: ${data?.length} bytes into file "$tmpPath"');
    } else if (name == NotificationNames.kPortableNetworkDecrypted) {
      // file data decrypted
      Uint8List? data = userInfo?['data'];
      String? path = userInfo?['path'];
      logInfo('[PNF] onDecrypted: ${data?.length} bytes into file "$path", $url');
    } else if (name == NotificationNames.kPortableNetworkDownloadSuccess) {
      // file data downloaded
      Uint8List? data = userInfo?['data'];
      logDebug('[PNF] onSuccess: ${data?.length} bytes, $url');
    } else if (name == NotificationNames.kPortableNetworkError) {
      // error
      String? error = userInfo?['error'];
      logError('[PNF] onError: $error, $url, $this');
    } else {
      assert(false, 'LNC name error: $name');
    }
    // refresh
    if (mounted) {
      setState(() {
      });
    }
  }

}
