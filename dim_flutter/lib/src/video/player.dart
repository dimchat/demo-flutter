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
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:lnc/log.dart';

import '../screens/cast.dart';
import '../screens/device.dart';
import '../screens/picker.dart';
import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';

import 'controller.dart';
import 'playing.dart';


/// Stateful widget to fetch and then display video content.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage(this.playingItem, {this.onShare, super.key,});

  final MediaItem playingItem;

  Uri? get url => playingItem.url;

  String get title {
    String text = playingItem.title;
    return text.isNotEmpty ? text :  'Video Player'.tr;
  }

  Uri? get cover => playingItem.cover;
  String? get filename => playingItem.filename;

  final OnVideoShare? onShare;

  final Color color = CupertinoColors.white;
  final Color bgColor = CupertinoColors.black;

  static void openVideoPlayer(BuildContext context, MediaItem playingItem, {
    OnVideoShare? onShare,
  }) => showPage(
    context: context,
    builder: (context) => VideoPlayerPage(playingItem, onShare: onShare,),
  );

  @override
  State<StatefulWidget> createState() => _VideoAppState();

}


class _VideoAppState extends State<VideoPlayerPage> with Logging {

  final PlayerController _playerController = PlayerController();

  String? _error;

  void openVideo(Uri url) {
    logInfo('[Video Player] remote url: $url');
    _playerController.openVideo(url).then((chewie) {
      // auto start playing
      setState(() {});
    }).onError((error, stackTrace) {
      setState(() => _error = '$error');
    });
  }

  @override
  void initState() {
    super.initState();
    // preparing video player controller
    var m3u8 = widget.url;
    if (m3u8 != null) {
      openVideo(m3u8);
    }
    // prepare screen manager
    var man = ScreenManager();
    man.addDiscoverer(CastScreenDiscoverer());
  }

  @override
  void dispose() {
    _playerController.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    // backgroundColor: Styles.colors.scaffoldBackgroundColor,
    backgroundColor: widget.bgColor,
    navigationBar: CupertinoNavigationBar(
      // backgroundColor: Styles.colors.appBardBackgroundColor,
      backgroundColor: widget.bgColor,
      middle: Text(widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          // color: Styles.colors.primaryTextColor,
          color: widget.color,
        ),
      ),
      trailing: _trailing(context),
    ),
    child: Center(
      child: _playerController.chewie ?? _loading(),
    ),
  );

  Widget? _trailing(BuildContext context) {
    Widget? castBtn = _castButton(context);
    Widget? shareBtn = _shareButton();
    if (castBtn == null) {
      return shareBtn;
    } else if (shareBtn == null) {
      return castBtn;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        castBtn,
        shareBtn,
      ],
    );
  }

  Widget? _castButton(BuildContext context) {
    var chewie = _playerController.chewieController;
    if (chewie == null) {
      return null;
    }
    var m3u8 = widget.url;
    if (m3u8 == null) {
      logError('playing URL not exists: ${widget.playingItem}');
      return null;
    }
    return IconButton(
      icon: Icon(
        AppIcons.airPlayIcon,
        size: Styles.navigationBarIconSize,
        color: widget.color,
      ),
      onPressed: () {
        chewie.pause();
        AirPlayPicker.open(context, m3u8);
      },
    );
  }

  Widget? _shareButton() {
    OnVideoShare? onShare = widget.onShare;
    if (onShare == null) {
      return null;
    }
    return IconButton(
      icon: Icon(
        AppIcons.shareIcon,
        size: Styles.navigationBarIconSize,
        color: widget.color,
      ),
      onPressed: () => onShare(widget.playingItem,
      ),
    );
  }

  Widget _loading() {
    Widget indicator;
    Widget message;
    TextStyle textStyle = TextStyle(
      color: widget.color,
      fontSize: 14,
      decoration: TextDecoration.none,
    );
    var m3u8 = widget.url;
    if (m3u8 == null) {
      logWarning('playing URL not found: ${widget.playingItem}');
      return Container();
    }
    String urlString = m3u8.toString();
    urlString = PlayerController.cutLiveUrlString(urlString) ?? urlString;
    if (_error == null) {
      indicator = CupertinoActivityIndicator(color: widget.color,);
      message = Text('Loading "@url" ...'.trParams({
        'url': urlString,
      }), style: textStyle,);
    } else {
      indicator = const Icon(AppIcons.decryptErrorIcon, color: CupertinoColors.systemRed,);
      message = Text('Failed to load "@url".'.trParams({
        'url': urlString,
      }), style: textStyle,);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        indicator,
        Container(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
          child: message,
        ),
      ],
    );
  }

}
