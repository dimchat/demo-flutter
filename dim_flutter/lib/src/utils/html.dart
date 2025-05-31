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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/plugins.dart';

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

  /// "data:image/png;base64,{BASE64_ENCODE}"
  static Uri encodeImageData(Uint8List img, {String mimeType = 'image/png'}) {
    var ted = Base64Data.fromData(img);
    var url = ted.encode(mimeType);
    return Uri.parse(url);
  }

}

abstract class DomainNameServer {

  static final _domain = RegExp(r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$');

  static final _address = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  static bool isDomainName(String text) => _domain.hasMatch(text);

  static bool isIPAddress(String text) {
    if (!_address.hasMatch(text)) {
      return false;
    }
    var array = text.split('.');
    if (array.length != 4) {
      return false;
    }
    for (var item in array) {
      var num = int.tryParse(item);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }
    return true;
  }

}
