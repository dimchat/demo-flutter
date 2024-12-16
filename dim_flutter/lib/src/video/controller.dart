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
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lnc/log.dart';
import 'package:video_player/video_player.dart';

import '../common/platform.dart';
import '../utils/html.dart';

import 'controls.dart';
import 'metronome.dart';


// protected
class PlayerController {

  bool _destroyed = false;

  /// Video Player Controller
  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? get videoPlayerController => _videoPlayerController;
  Future<void> setVideoPlayerController(VideoPlayerController? controller) async {
    var old = _videoPlayerController;
    if (old != null && old != controller) {
      if (old.value.isPlaying) {
        await old.pause();
      }
      await old.dispose();
    }
    _videoPlayerController = controller;
  }

  /// Chewie Controller
  ChewieController? _chewieController;
  ChewieController? get chewieController => _chewieController;
  Future<void> setChewieController(ChewieController? controller) async {
    var old = _chewieController;
    if (old != null && old != controller) {
      if (old.isPlaying) {
        await old.pause();
      }
      old.dispose();
    }
    _chewieController = controller;
  }

  Chewie? get chewie {
    var controller = _chewieController;
    return controller == null ? null : Chewie(controller: controller);
  }

  Future<void> destroy() async {
    _destroyed = true;
    await closeVideo();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> closeVideo() async {
    await setVideoPlayerController(null);
    await setChewieController(null);
  }

  /// Start playing URL
  Future<ChewieController?> openVideo(Uri url) async {
    // patch for Windows
    DevicePlatform.patchVideoPlayer();
    //
    //  0. check 'live' in url string
    //
    bool isLive = false;
    String? liveUrl = cutLiveUrlString(url.toString());
    if (liveUrl != null) {
      url = HtmlUri.parseUri(liveUrl) ?? url;
      isLive = true;
    }
    //
    //  1. create video player controller with network URL
    //
    var videoPlayerController = VideoPlayerController.networkUrl(url);
    //
    //  2. create chewie controller
    //
    ChewieController chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      // autoPlay: isLive,
      // zoomAndPan: true,
      looping: isLive,
      isLive: isLive,
      showOptions: false,
      allowedScreenSleep: false,
      customControls: const CustomControls(),
      // fullScreenByDefault: true,
      deviceOrientationsAfterFullScreen: _deviceOrientations(),
    );
    //
    //  3. load & play
    //
    await videoPlayerController.initialize();
    await chewieController.play();
    // OK
    await setVideoPlayerController(videoPlayerController);
    await setChewieController(chewieController);
    // check destroyed
    if (_destroyed) {
      // if video player controller was destroyed before loading finished,
      // close it
      Log.warning('video controller destroyed.');
      await closeVideo();
      return null;
    }
    var metronome = VideoPlayerMetronome();
    await metronome.seekLastPosition(videoPlayerController);
    return chewieController;
  }

  static List<DeviceOrientation> _deviceOrientations() {
    Size size = Get.size;
    if (size.width <= 0 || size.height <= 0) {
      Log.error('window size error: $size');
    } else if (size.width < 640 || size.height < 640) {
      Log.info('window size: $size, this is a phone');
      return [DeviceOrientation.portraitUp];
    } else {
      Log.info('window size: $size, this is a tablet?');
    }
    return DeviceOrientation.values;
  }

  static String? cutLiveUrlString(String urlString) {
    // check "...#live"
    if (urlString.endsWith('#live')) {
      return urlString.substring(0, urlString.length - 5);
    }
    // check "...#live/stream.m3u8"
    int pos = urlString.lastIndexOf('#live/');
    if (pos > 0) {
      return urlString.substring(0, pos);
    }
    // not a live URL string
    return null;
  }

}
