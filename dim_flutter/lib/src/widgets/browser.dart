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
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:lnc/lnc.dart' show Log;

import 'alert.dart';
import 'styles.dart';

class Browser extends StatefulWidget {
  const Browser({super.key, required this.uri, required this.title});

  final Uri uri;
  final String title;

  static void open(BuildContext context, {required String url, required String title}) {
    Uri? uri = parseUri(url);
    if (uri == null) {
      Alert.show(context, 'Error', 'Failed to open URL: $url');
    } else {
      showCupertinoDialog(context: context,
        builder: (context) => Browser(uri: uri, title: title),
      );
    }
  }

  static Uri? parseUri(String? urlString) {
    if (urlString == null || !urlString.contains('://')) {
      Log.error('URL error: $urlString');
      return null;
    }
    try {
      return Uri.parse(urlString);
    } on FormatException catch (e) {
      Log.error('URL error: $e, $urlString');
      return null;
    }
  }

  @override
  State<Browser> createState() => _BrowserState();

}

class _BrowserState extends State<Browser> {

  int _progress = 0;

  final InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
    ),
    android: AndroidInAppWebViewOptions(
      useHybridComposition: true,
      forceDark: AndroidForceDark.FORCE_DARK_AUTO,
    ),
    ios: IOSInAppWebViewOptions(
      allowsInlineMediaPlayback: true,
    )
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: Text(widget.title, style: Facade.of(context).styles.titleTextStyle),
      trailing: _progress <= 99 ? const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2.0)) : null,
    ),
    body: Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: widget.uri,
          ),
          initialOptions: options,
          onProgressChanged: (controller, progress) => setState(() {
            _progress = progress;
          }),
        ),
        if (_progress <= 99)
        Container(
          color: Colors.black54,
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 16),
          child: Text('$_progress% | ${widget.uri} ...',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              overflow: TextOverflow.ellipsis,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    ),
  );
}
