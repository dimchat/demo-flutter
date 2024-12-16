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
import 'package:video_player/video_player.dart';

import 'package:lnc/log.dart';
import 'package:stargate/startrek.dart';

import '../common/platform.dart';


class VideoPlayerMetronome with Logging {
  factory VideoPlayerMetronome() => _instance;
  static final VideoPlayerMetronome _instance = VideoPlayerMetronome._internal();
  VideoPlayerMetronome._internal() {
    _metronome = Metronome(Duration.millisecondsPerSecond);
    /*await */_metronome.start();
  }

  late final Metronome _metronome;

  void addTicker(Ticker ticker) => _metronome.addTicker(ticker);

  void removeTicker(Ticker ticker) => _metronome.removeTicker(ticker);

  /// playback positions
  final Map<String, Duration> _playingPositions = {};

  /// playback speed
  double _speed = 1.0;

  bool speedUp = false;

  double getPlaybackSpeed(bool isLive) {
    if (isLive) {
      return 1.0;
    } else if (speedUp) {
      return _speed * 2.0;
    } else {
      return _speed;
    }
  }

  void changePlaybackSpeed() {
    if (_speed < 1.0) {
      _speed = 1.0;
    } else if (_speed < 1.25) {
      _speed = 1.25;
    } else if (_speed < 1.5) {
      _speed = 1.5;
    } else if (_speed < 2.0) {
      _speed = 2.0;
    } else {
      _speed = 0.5;
    }
  }

  void setPlaybackSpeed(VideoPlayerController controller, bool isLive) {
    double playbackSpeed = getPlaybackSpeed(isLive);
    controller.setPlaybackSpeed(playbackSpeed);
  }

  void _keepPlaybackSpeed(VideoPlayerController controller, bool isLive) {
    if (isLive || !controller.value.isPlaying) {
      return;
    }
    double playbackSpeed = getPlaybackSpeed(isLive);
    if (controller.value.playbackSpeed != playbackSpeed) {
      controller.setPlaybackSpeed(playbackSpeed);
    } else if (DevicePlatform.isAndroid) {
      // Android is OK
    } else if (DevicePlatform.isWindows) {
      // Windows is OK
    } else if (playbackSpeed != 1.0) {
      // fix for iOS, ...
      controller.setPlaybackSpeed(playbackSpeed);
    }
  }

  void _storePlaybackPosition(String url, Duration? position, bool isLive) {
    if (position == null) {
      return;
    } else if (isLive) {
      logInfo('no need to store position for live video: $url');
      return;
    }
    _playingPositions[url] = position;
  }

  Future<bool> seekLastPosition(VideoPlayerController controller) async {
    String url = controller.dataSource;
    Duration? position = _playingPositions[url];
    logInfo('last position: $position, $url');
    if (position == null || position.inSeconds < 16) {
      return false;
    }
    await controller.seekTo(position);
    return true;
  }

  Future<bool> touchPlayerControllers(VideoPlayerController controller, ChewieController? chewie) async {
    if (chewie == null) {
      assert(false, 'should not happen');
      return false;
    }
    // keep speed
    bool isLive = chewie.isLive;
    _keepPlaybackSpeed(controller, isLive);
    // store position
    String url = controller.dataSource;
    Duration? position = await controller.position;
    _storePlaybackPosition(url, position, isLive);
    return true;
  }

}
