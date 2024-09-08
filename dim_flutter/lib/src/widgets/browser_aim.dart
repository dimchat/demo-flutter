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

import 'package:lnc/log.dart';

import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';
import '../utils/html.dart';

import 'browser.dart';


/// Support
/// ~~~~~~~
///   1. Android
///   2. iOS
///   3. macOS
///
/// URL:
///   https://inappwebview.dev/docs/intro/

class BrowserState extends State<Browser> {

  InAppWebViewController? _controller;

  int _progress = 0;

  Uri? _url;
  String? _title;

  Uri get url => _url ?? widget.url;
  String get title => _title ?? '';

  String? get html => _url == null ? widget.html : null;

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
      trailing: _naviItems(context),
    ),
    body: Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        // FIXME: Use PopScope instead.
        WillPopScope(
          onWillPop: () async {
            var controller = _controller;
            if (controller != null && await controller.canGoBack()) {
              await controller.goBack();
              return false;
            }
            return true;
          },
          child: _webView(context),
        ),
        if (_progress < 100)
          _statusBar(),
      ],
    ),
  );

  Widget? _naviItems(BuildContext context) {
    Widget? one = _progress <= 99 ? _indicator() : _shareButton();
    Widget? two = _controller == null ? null : IconButton(
      onPressed: () => closePage(context),
      icon: const Icon(
        AppIcons.closeIcon,
        size: Styles.navigationBarIconSize,
        // color: Styles.avatarColor,
      ),
    );
    return one == null ? two : two == null ? one : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        one,
        two,
      ],
    );
  }
  // => _progress <= 99 ? _indicator() : _shareButton();
  Widget _indicator() => const SizedBox(
    width: Styles.navigationBarIconSize, height: Styles.navigationBarIconSize,
    child: CircularProgressIndicator(strokeWidth: 2.0),
  );
  Widget? _shareButton() {
    OnWebShare? onShare = widget.onWebShare;
    if (onShare == null) {
      return null;
    }
    Uri target = url;
    if (target.toString() == 'about:blank') {
      target = widget.url;
    }
    // TODO: get page desc & icon
    return IconButton(
      icon: const Icon(
        AppIcons.shareIcon,
        size: Styles.navigationBarIconSize,
        // color: Styles.avatarColor,
      ),
      onPressed: () => onShare(target, title: title, desc: null, icon: null),
    );
  }

  Widget _webView(BuildContext ctx) => InAppWebView(
    initialUrlRequest: _BrowserUtils.getURLRequest(url),
    initialData: _BrowserUtils.getWebViewData(url, html),
    initialOptions: _BrowserUtils.getWebViewOptions(),
    onProgressChanged: (controller, progress) => setState(() {
      _progress = progress;
    }),
    onLoadStart: (controller, url) => setState(() {
      _controller = controller;
      _url = url;
    }),
    onTitleChanged: (controller, title) => setState(() {
      _title = title;
    }),
    shouldOverrideUrlLoading: (controller, action) {
      var url = action.request.url;
      if (url == null || systemSchemes.contains(url.scheme)) {
        Log.info('loading URL: $url');
        // allow the request
        return Future.value(NavigationActionPolicy.ALLOW);
      }
      // Launch the App
      Browser.launchURL(ctx, url);
      // and cancel the request
      return Future.value(NavigationActionPolicy.CANCEL);
    },
  );
  static final List<String> systemSchemes = [
    "http", "https",
    "file",
    "chrome",
    "data",
    "javascript",
    "about",
  ];

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

abstract class _BrowserUtils {

  //
  //  InAppWebView
  //

  static URLRequest? getURLRequest(Uri url) {
    String? html = HtmlUri.getHtmlString(url);
    if (html == null) {
      // http:
      // https:
      return URLRequest(
        url: url,
      );
    } else {
      // data:text/html
      return null;
    }
  }

  static InAppWebViewInitialData? getWebViewData(Uri url, String? html) {
    html ??= HtmlUri.getHtmlString(url);
    if (html == null) {
      // http:
      // https:
      return null;
    } else {
      // data:text/html
      return InAppWebViewInitialData(
        data: html,
        // TODO: baseUrl
      );
    }
  }

  static InAppWebViewGroupOptions getWebViewOptions() => InAppWebViewGroupOptions(
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

}