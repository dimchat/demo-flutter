/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
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
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';

import 'video_controls.dart';


typedef OnVideoShare = void Function(Uri url, {
  required String title, required String? filename, required String? snapshot,
});


/// Stateful widget to fetch and then display video content.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage(this.url, this.pnf, {this.onShare, super.key,});

  final Uri url;
  final PortableNetworkFile pnf;

  String? get title => pnf['title'];
  String? get snapshot => pnf['snapshot'];
  String? get filename => pnf.filename;

  final OnVideoShare? onShare;

  final Color color = CupertinoColors.white;
  final Color bgColor = CupertinoColors.black;

  static void open(BuildContext context, Uri url, PortableNetworkFile pnf,
      {OnVideoShare? onShare,}) => showPage(
    context: context,
    builder: (context) => VideoPlayerPage(url, pnf, onShare: onShare,),
  );

  @override
  State<StatefulWidget> createState() => _VideoAppState();

}

class _VideoAppState extends State<VideoPlayerPage> {

  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  String? _error;

  @override
  void initState() {
    super.initState();
    Log.info('[Video Player] remote url: ${widget.url}');
    // preparing video player controller
    _videoPlayerController = VideoPlayerController.networkUrl(widget.url);
    _videoPlayerController.initialize().then((_) {
      setState(() {});
      // auto start playing
      _videoPlayerController.play();
    }).onError((error, stackTrace) {
      setState(() {
        _error = '$error';
      });
    });
    // preparing chewie controller
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      showOptions: false,
      allowedScreenSleep: false,
      customControls: const CustomControls(),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    // backgroundColor: Styles.colors.scaffoldBackgroundColor,
    backgroundColor: widget.bgColor,
    navigationBar: CupertinoNavigationBar(
      // backgroundColor: Styles.colors.appBardBackgroundColor,
      backgroundColor: widget.bgColor,
      middle: Text(widget.title ?? 'Video Player'.tr,
        style: TextStyle(
          // color: Styles.colors.primaryTextColor,
          color: widget.color,
        ),
      ),
      trailing: _shareButton(),
    ),
    child: Center(
      child: _videoPlayerController.value.isInitialized ? Chewie(
        controller: _chewieController,
      ) : _loading(),
    ),
  );

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
      onPressed: () => onShare(widget.url,
        title: widget.title ?? '',
        filename: widget.filename,
        snapshot: widget.snapshot,
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
    if (_error == null) {
      indicator = CupertinoActivityIndicator(color: widget.color,);
      message = Text('Loading "@url" ...'.trParams({
        'url': widget.url.toString(),
      }), style: textStyle,);
    } else {
      indicator = const Icon(AppIcons.decryptErrorIcon, color: CupertinoColors.systemRed,);
      message = Text('Failed to load "@url".'.trParams({
        'url': widget.url.toString(),
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
