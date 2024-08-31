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
import 'package:url_launcher/url_launcher.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import '../pnf/image.dart';
import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';
import '../utils/html.dart';

import 'alert.dart';


typedef OnWebShare = void Function(Uri url, {
  required String title, required String? desc, required String? icon,
});


class Browser extends StatefulWidget {
  const Browser({super.key, required this.url, this.html, this.onWebShare});

  final Uri url;
  final String? html;
  final OnWebShare? onWebShare;

  static void open(BuildContext context, String? urlString, {
    OnWebShare? onWebShare,
  }) {
    Uri? url = HtmlUri.parseUri(urlString);
    Log.info('URL length: ${urlString?.length}: $url');
    if (url == null) {
      Alert.show(context, 'Error', 'Failed to open URL: $urlString');
    } else {
      openURL(context, url, onWebShare: onWebShare);
    }
  }
  static void openURL(BuildContext context, Uri url, {
    OnWebShare? onWebShare,
  }) => showPage(context: context,
    builder: (context) => Browser(url: url, onWebShare: onWebShare,),
  );

  static void launch(BuildContext context, String? urlString, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) {
    Uri? url = HtmlUri.parseUri(urlString);
    Log.info('URL length: ${urlString?.length}: $url');
    if (url == null) {
      Alert.show(context, 'Error', 'Failed to launch URL: $urlString');
    } else {
      launchURL(context, url, mode: mode);
    }
  }
  static void launchURL(BuildContext context, Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) => canLaunchUrl(url).then((can) {
    if (!can) {
      Alert.show(context, 'Error', 'Cannot launch URL: $url');
      // return;
      Log.warning('cannot launch URL: $url');
    }
    launchUrl(url, mode: mode).then((ok) {
      if (ok) {
        Log.info('launch URL: $url');
      } else {
        Alert.show(context, 'Error', 'Failed to launch URL: $url');
      }
    });
  });

  // create web view
  static Widget view(BuildContext context, Uri url, {
    String? html,
  }) => Browser(url: url, html: html,);

  @override
  State<Browser> createState() => _BrowserState();

}

class _BrowserState extends State<Browser> {

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
          child: _webView(),
        ),
        // _webView(),
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

  Widget _webView() => InAppWebView(
    initialUrlRequest: HtmlUri.getURLRequest(url),
    initialData: HtmlUri.getWebViewData(url, html),
    initialOptions: HtmlUri.getWebViewOptions(),
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
    shouldOverrideUrlLoading: (controller, action) async {
      var url = action.request.url;
      if (url == null || systemSchemes.contains(url.scheme)) {
        Log.info('loading URL: $url');
        return NavigationActionPolicy.ALLOW;
      } else if (await canLaunchUrl(url)) {
        Log.info('launch other app with URL: $url');
      } else {
        // FIXME: adding 'queries' in AndroidManifest.xml
        Log.warning('failed to check URL: $url');
        // return NavigationActionPolicy.ALLOW;
      }
      // Launch the App
      await launchUrl(url);
      // and cancel the request
      return NavigationActionPolicy.CANCEL;
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


/// WebPageView
class PageContentView extends StatelessWidget {
  const PageContentView({super.key, required this.content, this.onTap, this.onLongPress});

  final PageContent content;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

  Widget? get icon {
    var small = content['icon'];
    if (small is String) {
      return ImageUtils.getImage(small);
    }
    assert(small == null, 'page icon error: %small');
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
