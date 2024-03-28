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
import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lnc/log.dart';
import 'package:video_player/video_player.dart';

import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';


typedef OnVideoShare = void Function(Uri url);


/// Stateful widget to fetch and then display video content.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage(this.url, this.pnf, {this.onShare, super.key,});

  final Uri url;
  final PortableNetworkFile pnf;

  String? get title => pnf['title'];

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
  late VideoPlayerController _controller;
  bool? _playing;
  bool? _showProgress;
  double _currentPosition = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    Log.info('[Video Player] remote url: ${widget.url}');
    _controller = VideoPlayerController.networkUrl(widget.url);
    _controller.initialize().then((_) {
      // ensure the first frame is shown after the video is initialized,
      // even before the play button has been pressed.
      setState(() {
        _playing = true;
      });
      // auto start playing
      _controller.play();
    }).onError((error, stackTrace) {
      setState(() {
        _error = '$error';
      });
    });
    _controller.addListener(() => setState(() {
      _currentPosition = _controller.value.position.inSeconds.toDouble();
    }));
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // backgroundColor: Styles.colors.scaffoldBackgroundColor,
    backgroundColor: widget.bgColor,
    extendBodyBehindAppBar: true,
    appBar: _showProgress == false ? null : CupertinoNavigationBar(
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
    body: Center(
      child: SingleChildScrollView(
        child: _controller.value.isInitialized ? _body() : _loading(),
      ),
    ),
    // floatingActionButton: _button(),
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
      onPressed: () => onShare(widget.url),
    );
  }

  Widget _loading() {
    Widget indicator;
    Widget message;
    if (_error == null) {
      indicator = CupertinoActivityIndicator(color: widget.color,);
      message = Text('Loading "@url" ...'.trParams({
        'url': widget.url.toString(),
      }), style: TextStyle(color: widget.color),);
    } else {
      indicator = const Icon(AppIcons.decryptErrorIcon, color: CupertinoColors.systemRed,);
      message = Text('Failed to load "@url".'.trParams({
        'url': widget.url.toString(),
      }), style: TextStyle(color: widget.color),);
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

  Widget _body() => Stack(
    alignment: AlignmentDirectional.bottomCenter,
    children: [
      AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: GestureDetector(
          child: VideoPlayer(_controller),
          onTap: () => setState(() {
            _showProgress = _showProgress == false;
          }),
          onDoubleTap: () => setState(() => _togglePlaying()),
        ),
      ),
      SizedBox(
        height: 48,
        child: _slider(),
      ),
    ],
  );

  Widget _slider() {
    TextStyle textStyle = TextStyle(color: widget.color);
    var bufferedEnd = _controller.value.buffered.map((range) => range.end).toList();
    var maxBufferedEnd = bufferedEnd.isNotEmpty ? bufferedEnd.reduce((a, b) => a > b ? a : b) : Duration.zero;
    final buf = maxBufferedEnd.inSeconds.toDouble();
    double pos = _currentPosition;
    double len = _controller.value.duration.inSeconds.toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_playing != null)
          _button(),
        Text(_time(pos), style: textStyle),
        if (_showProgress == false)
        Expanded(child: Container(),),
        if (_showProgress != false)
        Expanded(child: Slider(onChanged: (value) {
          setState(() => _currentPosition = value);
          _controller.seekTo(Duration(seconds: value.toInt()));
        }, value: pos, max: len, min: 0.0,
          secondaryTrackValue: buf,
          thumbColor: CupertinoColors.inactiveGray,
          activeColor: CupertinoColors.systemFill,
          inactiveColor: CupertinoColors.secondarySystemFill,
          secondaryActiveColor: CupertinoColors.systemYellow,
        )),
        Text(_time(len), style: textStyle),
        const SizedBox(width: 16,),
      ],
    );
  }

  void _togglePlaying() {
    if (_playing == true) {
      _playing = false;
      _controller.pause();
    } else if (_playing == false) {
      _playing = true;
      _controller.play();
    } else {
      // initializing
    }
  }

  Widget _button() {
    if (_controller.value.isCompleted) {
      _playing = false;
    }
    return IconButton(
      onPressed: () => setState(() => _togglePlaying()),
      icon: Icon(
        _playing == false ? Icons.play_arrow : Icons.pause,
        color: widget.color,
      ),
    );
  }

}

String _time(double value) {
  int timestamp = value.toInt();
  int seconds = timestamp % 60;
  int minutes = timestamp ~/ 60 % 60;
  int hours = timestamp ~/ 3600;
  String mm = minutes.toString().padLeft(2, '0');
  String ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    String hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  } else {
    return '$mm:$ss';
  }
}
