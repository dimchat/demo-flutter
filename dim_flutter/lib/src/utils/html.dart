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
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import '../widgets/browser.dart';


abstract class HtmlUri {

  static final Uri blank = parseUri('about:blank')!;

  static Uri? parseUri(String? urlString) {
    if (urlString == null) {
      return null;
    } else if (urlString.contains('://')) {
      // - http://
      // - https://
    } else if (urlString.startsWith('data:')) {
      // - data:text/html;charset=UTF-8;base64,
    } else if (urlString.startsWith('about:')) {
      // - about:blank
    } else {
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

  static String getUriString(PageContent content) {
    // check HTML
    String? html = content.getString('HTML', null);
    if (html != null) {
      // assert(html.isNotEmpty, 'page content error: $content');
      String base64 = Base64.encode(UTF8.encode(html));
      return 'data:text/html;charset=UTF-8;base64,$base64';
    }
    // check URL
    String? url = content.getString('URL', null);
    if (url == null || url.isEmpty || url == 'about:blank') {
      url = 'data:text/html,';
      // content['URL'] = url;
    }
    return url;
  }

  static String? getHtmlString(Uri url) {
    String urlString = url.toString();
    if (!urlString.startsWith('data:text/html')) {
      return null;
    }
    int pos = urlString.indexOf(',');
    if (pos < 0) {
      Log.error('web page url error: $url');
      return '';
    }
    String base64 = urlString.substring(pos + 1);
    return UTF8.decode(Base64.decode(base64)!);
  }

  static bool setHtmlString(Uri url, PageContent content) {
    String? html = getHtmlString(url);
    if (html == null) {
      return false;
    }
    content['URL'] = 'data:text/html,';
    content['HTML'] = html;
    return true;
  }

  static void showWebPage(BuildContext context,
      {required PageContent content, OnWebShare? onWebShare}) {
    String url = getUriString(content);
    Browser.open(context, url, onWebShare: onWebShare);
  }

  //
  //  InAppWebView
  //

  static URLRequest? getURLRequest(Uri url) {
    String? html = getHtmlString(url);
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
    html ??= getHtmlString(url);
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
