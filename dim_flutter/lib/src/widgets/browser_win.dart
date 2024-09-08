/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:webview_windows/webview_windows.dart';

import 'browser.dart';


/// Support
/// ~~~~~~~
///   1. Windows
///
/// URL:
///   https://pub.dev/packages/webview_windows

class BrowserState extends State<Browser> {

  final WebviewController _controller = WebviewController();
  final TextEditingController _textController = TextEditingController();
  final List<StreamSubscription> _subscriptions = [];
  bool _isWebviewSuspended = false;

  @override
  void dispose() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    // Optionally initialize the webview environment using
    // a custom user data directory
    // and/or a custom browser executable directory
    // and/or custom chromium command line flags
    //await WebviewController.initializeEnvironment(
    //    additionalArguments: '--show-fps-counter');

    try {
      await _controller.initialize();
      _subscriptions.add(_controller.url.listen((url) {
        _textController.text = url;
      }));

      _subscriptions
          .add(_controller.containsFullScreenElementChanged.listen((flag) {
        debugPrint('Contains fullscreen element: $flag');
        // windowManager.setFullScreen(flag);
      }));

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadUrl('https://flutter.dev');

      if (!mounted) return;
      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Error'.tr),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Code: ${e.code}'),
                  Text('Message: ${e.message}'),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Continue'.tr),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ));
      });
    }
  }

  Widget compositeView() {
    if (!_controller.value.isInitialized) {
      return const Text(
        'Not Initialized',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 0,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'URL',
                      contentPadding: EdgeInsets.all(10.0),
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    controller: _textController,
                    onSubmitted: (val) {
                      _controller.loadUrl(val);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  splashRadius: 20,
                  onPressed: () {
                    _controller.reload();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.developer_mode),
                  tooltip: 'Open DevTools',
                  splashRadius: 20,
                  onPressed: () {
                    _controller.openDevTools();
                  },
                )
              ]),
            ),
            Expanded(
                child: Card(
                    color: Colors.transparent,
                    elevation: 0,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: Stack(
                      children: [
                        Webview(
                          _controller,
                          permissionRequested: _onPermissionRequested,
                        ),
                        StreamBuilder<LoadingState>(
                            stream: _controller.loadingState,
                            builder: (context, snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data == LoadingState.loading) {
                                return const LinearProgressIndicator();
                              } else {
                                return const SizedBox();
                              }
                            }),
                      ],
                    ))),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: _isWebviewSuspended ? 'Resume webview' : 'Suspend webview',
        onPressed: () async {
          if (_isWebviewSuspended) {
            await _controller.resume();
          } else {
            await _controller.suspend();
          }
          setState(() {
            _isWebviewSuspended = !_isWebviewSuspended;
          });
        },
        child: Icon(_isWebviewSuspended ? Icons.play_arrow : Icons.pause),
      ),
      appBar: AppBar(
          title: StreamBuilder<String>(
            stream: _controller.title,
            builder: (context, snapshot) {
              return Text(
                  snapshot.hasData ? snapshot.data! : 'WebView (Windows) Example');
            },
          )),
      body: Center(
        child: compositeView(),
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: Text('Deny'.tr),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: Text('Allow'.tr),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

}

final navigatorKey = GlobalKey<NavigatorState>();
