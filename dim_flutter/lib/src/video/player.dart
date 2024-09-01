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
import 'package:lnc/notification.dart' as lnc;
import 'package:pnf/dos.dart';
import 'package:stargate/startrek.dart' show Runner;

import '../common/constants.dart';
import '../screens/cast.dart';
import '../screens/device.dart';
import '../screens/picker.dart';
import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';

import 'controller.dart';
import 'playing.dart';
import 'tvbox.dart';


/// Stateful widget to fetch and then display video content.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage(this.playingItem, this.tvBox, {this.onShare, super.key,});

  final MediaItem playingItem;
  final TVBox? tvBox;

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
    builder: (context) => VideoPlayerPage(playingItem, null, onShare: onShare,),
  );

  static void openLivePlayer(BuildContext context, Uri livesUrl, {
    OnVideoShare? onShare,
  }) => showPage(
    context: context,
    builder: (context) => VideoPlayerPage(MediaItem(null),
      TVBox(livesUrl, {'url': livesUrl.toString()},),
      onShare: onShare,
    ),
  );

  @override
  State<StatefulWidget> createState() => _VideoAppState();

}


class _VideoAppState extends State<VideoPlayerPage> with Logging implements lnc.Observer {
  _VideoAppState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kVideoPlayerPlay);
  }

  final PlayerController _playerController = PlayerController();

  String? _error;

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kVideoPlayerPlay);
    _playerController.destroy();
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kVideoPlayerPlay) {
      Uri? url = info?['url'];
      String? title = info?['title'];
      if (url == null || title == null) {
        assert(false, 'video play info error: $info');
      } else {
        await _changeVideo(url, title);
      }
    }
  }

  Future<void> _changeVideo(Uri url, String title) async {
    await _playerController.closeVideo();
    var filename = Paths.filename(url.path);
    _error = null;
    widget.playingItem.refresh({
      'url': url.toString(),
      'URL': url.toString(),
      'title': title,
      'filename': filename,
    });
    widget.tvBox?.hidden = true;
    if (mounted) {
      setState(() {});
    }
    await Runner.sleep(milliseconds: 128);
    openVideo(url);
  }

  void openVideo(Uri url) {
    logInfo('[Video Player] remote url: $url');
    _playerController.openVideo(url).then((chewie) {
      // auto start playing
      setState(() {});
    }).onError((error, stackTrace) {
      setState(() => _error = '$error');
    });
  }

  void loadLives(TVBox tvBox) {
    tvBox.refresh().then((genres) {
    // show channels button
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
    // preparing tv box
    var tvBox = widget.tvBox;
    if (tvBox != null) {
      loadLives(tvBox);
    }
    // prepare screen manager
    var man = ScreenManager();
    man.addDiscoverer(CastScreenDiscoverer());
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
    child: _body(),
  );

  Widget _body() {
    // build main view
    Widget? chewie = _playerController.chewie;
    Widget? main = chewie ?? _loadingVideo() ?? _loadingLives();
    if (main != null) {
      main = Center(
        child: main,
      );
    }
    // build lives view
    Widget? lives = widget.tvBox?.view;
    if (lives != null) {
      lives = Container(
        alignment: Alignment.topRight,
        // margin: const EdgeInsets.only(right: 16, bottom: 72),
        child: lives,
      );
      lives = AnimatedOpacity(
        opacity: widget.tvBox?.hidden != false ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 512),
        child: lives,
      );
      lives = AnimatedSlide(
        offset: widget.tvBox?.hidden != false ? const Offset(1, 0) : Offset.zero,
        duration: const Duration(milliseconds: 512),
        child: lives,
      );
    }
    // combine
    return Stack(
      children: [
        if (main != null)
          main,
        if (lives != null)
          lives,
      ],
    );
  }

  Widget? _trailing(BuildContext context) {
    Widget? castBtn = _castButton(context);
    Widget? shareBtn = _shareButton();
    Widget? livesBtn = _livesButton();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (castBtn != null)
          castBtn,
        if (shareBtn != null)
          shareBtn,
        if (livesBtn != null)
          livesBtn,
      ],
    );
  }

  Widget? _livesButton() {
    var tvbox = widget.tvBox;
    if (tvbox == null) {
      return null;
    }
    var channelGroups = tvbox.lives;
    if (channelGroups == null || channelGroups.isEmpty) {
      return null;
    }
    return IconButton(
      icon: Icon(
        AppIcons.livesIcon,
        size: Styles.navigationBarIconSize,
        color: tvbox.hidden ? widget.color : Colors.blue,
      ),
      onPressed: () {
        setState(() {
          tvbox.hidden = !tvbox.hidden;
        });
      },
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
        AppIcons.shareIcon,
        size: Styles.navigationBarIconSize,
        color: widget.color,
      ),
      onPressed: () => onShare(widget.playingItem,
      ),
    );
  }

  Widget? _loadingLives() {
    Widget indicator;
    Widget message;
    TextStyle textStyle = TextStyle(
      color: widget.color,
      fontSize: 14,
      decoration: TextDecoration.none,
    );
    //
    //  check TV box
    //
    var tvBox = widget.tvBox;
    if (tvBox == null) {
      logWarning('TV box not found: $tvBox');
      return null;
    }
    var livesUrl = tvBox.livesUrl;
    String urlString = livesUrl.toString();
    var channelGroups = tvBox.lives;
    if (channelGroups == null) {
      // loading
      indicator = CupertinoActivityIndicator(color: widget.color,);
      message = Text('Loading "@url"'.trParams({
        'url': urlString,
      }), style: textStyle,);
    } else if (channelGroups.isEmpty) {
      // error
      indicator = const Icon(AppIcons.decryptErrorIcon, color: CupertinoColors.systemRed,);
      message = Text('Failed to load "@url".'.trParams({
        'url': urlString,
      }), style: textStyle,);
    } else {
      // success
      return null;
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

  Widget? _loadingVideo() {
    Widget indicator;
    Widget message;
    TextStyle textStyle = TextStyle(
      color: widget.color,
      fontSize: 14,
      decoration: TextDecoration.none,
    );
    //
    //  check playing item
    //
    var m3u8 = widget.url;
    if (m3u8 == null) {
      logWarning('playing URL not found: ${widget.playingItem}');
      return null;
    }
    String urlString = m3u8.toString();
    urlString = PlayerController.cutLiveUrlString(urlString) ?? urlString;
    if (_error == null) {
      // loading
      indicator = CupertinoActivityIndicator(color: widget.color,);
      message = Text('Loading "@url"'.trParams({
        'url': urlString,
      }), style: textStyle,);
    } else {
      // error
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
