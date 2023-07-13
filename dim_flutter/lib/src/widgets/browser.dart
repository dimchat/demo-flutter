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
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:lnc/lnc.dart' show Log;

import 'alert.dart';
import 'styles.dart';

class Browser extends StatefulWidget {
  const Browser({super.key, required this.uri, this.title});

  final Uri uri;
  final String? title;

  static void open(BuildContext context, {required String url, String? title}) {
    Uri? uri = parseUri(url);
    if (uri == null) {
      Alert.show(context, 'Error', 'Failed to open URL: $url');
    } else {
      if (title != null && title.isEmpty) {
        title = null;
      }
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

  Uri? _url;
  String? _title;

  Uri get url => _url ?? widget.uri;
  String get title => widget.title ?? _title ?? '';

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
      middle: Text(title, style: Facade.of(context).styles.titleTextStyle),
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
          onLoadStart: (controller, url) => setState(() {
            _url = url;
          }),
          onTitleChanged: (controller, title) => setState(() {
            _title = title;
          }),
        ),
        if (_progress <= 99)
        Container(
          color: Colors.black54,
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 16),
          child: Text('$_progress% | $url ...',
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


/// WebPageView
class PageContentView extends StatelessWidget {
  const PageContentView({super.key, required this.content, this.onTap});

  final GestureTapCallback? onTap;
  final PageContent content;

  Widget? get icon {
    try {
      Uint8List? icon = content.icon;
      if (icon != null) {
        return Image(image: MemoryImage(icon));
      }
    } catch (e) {
      Log.error('web page icon error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap ?? () => Browser.open(context, url: content.url, title: content.title),
    child: _widget(context),
  );

  Widget _widget(BuildContext context) {
    var colors = Facade.of(context).colors;
    var styles = Facade.of(context).styles;
    String url = content.url;
    String title = content.title;
    String desc = content.desc ?? '';
    Widget image = icon ?? Icon(Styles.webpageIcon, color: colors.pageMessageColor,);
    if (title.isEmpty) {
      title = url;
      url = '';
    } else if (desc.isEmpty) {
      desc = url;
      url = '';
    }
    return Container(
      color: colors.pageMessageBackgroundColor,
      padding: Styles.pageMessagePadding,
      width: 256,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            maxLines: 2,
            style: styles.pageTitleTextStyle,
          ),
          Row(
            children: [
              Expanded(
                child: Text(desc,
                  maxLines: 3,
                  style: styles.pageDescTextStyle,
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.all(
                    Radius.elliptical(8, 8)
                ),
                child: SizedBox(
                  width: 48, height: 48,
                  // color: CupertinoColors.systemIndigo,
                  child: image,
                ),
              ),
            ],
          ),
          if (url.isNotEmpty)
            Text(url,
              style: styles.pageDescTextStyle,
            ),
        ],
      ),
    );
  }

}
