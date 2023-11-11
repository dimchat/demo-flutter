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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' show Log;

import '../ui/icons.dart';
import '../ui/styles.dart';

import 'alert.dart';
import 'browse_html.dart';


typedef OnWebShare = void Function(Uri url, {required String title, String? desc, Uint8List? icon});


class Browser extends StatefulWidget {
  const Browser({super.key, required this.uri, this.onShare});

  final Uri uri;
  final OnWebShare? onShare;

  static void open(BuildContext context, {required String url, OnWebShare? onShare}) {
    Uri? uri = HtmlUri.parseUri(url);
    Log.info('URL length: ${url.length}: $uri');
    if (uri == null) {
      Alert.show(context, 'Error', 'Failed to open URL: $url');
    } else {
      showCupertinoDialog(context: context,
        builder: (context) => Browser(uri: uri, onShare: onShare,),
      );
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
  String get title => _title ?? '';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: Text(title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Styles.titleTextStyle,
      ),
      trailing: _naviItem(),
    ),
    body: Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        _webView(),
        if (_progress <= 99)
          _statusBar(),
      ],
    ),
  );

  Widget? _naviItem() => _progress <= 99 ? _indicator() : _shareButton();
  Widget _indicator() => const SizedBox(
    width: Styles.navigationBarIconSize, height: Styles.navigationBarIconSize,
    child: CircularProgressIndicator(strokeWidth: 2.0),
  );
  Widget? _shareButton() {
    OnWebShare? onShare = widget.onShare;
    if (onShare == null) {
      return null;
    }
    Uri target = url;
    if (target.toString() == 'about:blank') {
      target = widget.uri;
    }
    return IconButton(
      icon: const Icon(
        AppIcons.shareIcon,
        size: Styles.navigationBarIconSize,
        // color: Styles.avatarColor,
      ),
      onPressed: () => onShare(target, title: title),
    );
  }

  Widget _webView() => InAppWebView(
    initialUrlRequest: HtmlUri.getURLRequest(widget.uri),
    initialData: HtmlUri.getWebViewData(widget.uri),
    initialOptions: HtmlUri.getWebViewOptions(),
    onProgressChanged: (controller, progress) => setState(() {
      _progress = progress;
    }),
    onLoadStart: (controller, url) => setState(() {
      _url = url;
    }),
    onTitleChanged: (controller, title) => setState(() {
      _title = title;
    }),
  );

  Widget _statusBar() => Container(
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
  );
}


/// WebPageView
class PageContentView extends StatelessWidget {
  const PageContentView({super.key, required this.content, this.onTap, this.onLongPress});

  final PageContent content;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

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
    onTap: onTap ?? () => HtmlUri.showWebPage(context, content: content),
    onLongPress: onLongPress,
    child: _widget(context),
  );

  Widget _widget(BuildContext context) {
    var colors = Styles.colors;
    String url = content.url.toString();
    String title = content.title;
    String desc = content.desc ?? '';
    Widget image = icon ?? Icon(AppIcons.webpageIcon, color: colors.pageMessageColor,);
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
      // width: 256,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            maxLines: 2,
            style: Styles.pageTitleTextStyle,
          ),
          Row(
            children: [
              Expanded(
                child: Text(desc,
                  maxLines: 3,
                  style: Styles.pageDescTextStyle,
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
              style: Styles.pageDescTextStyle,
            ),
        ],
      ),
    );
  }

}
