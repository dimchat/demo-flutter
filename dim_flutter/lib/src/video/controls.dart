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
import 'package:video_player/video_player.dart';

import 'package:chewie/chewie.dart';

import 'package:chewie/src/notifiers/player_notifier.dart';
import 'package:chewie/src/material/material_progress_bar.dart';
import 'package:chewie/src/helpers/utils.dart';
import 'package:chewie/src/center_play_button.dart';

import 'package:provider/provider.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/ws.dart' show Ticker;

import '../utils/keyboard.dart';
import 'metronome.dart';


class CustomControls extends StatefulWidget {
  const CustomControls({super.key});

  @override
  State<StatefulWidget> createState() => _CustomControlsState();

}

class _CustomControlsState extends State<CustomControls>
    with SingleTickerProviderStateMixin, Logging implements Ticker {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  late var _subtitlesPosition = Duration.zero;
  bool _subtitleOn = false;
  Timer? _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;
  Timer? _bufferingDisplayTimer;
  bool _displayBufferingIndicator = false;

  final barHeight = 48.0 * 1.5;
  final marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieController? _chewieController;

  final FocusNode _focusNode = FocusNode();

  // We know that _chewieController is set in didChangeDependencies
  ChewieController get chewieController => _chewieController!;

  @override
  Future<void> tick(DateTime now, Duration elapsed) async {
    var metronome = VideoPlayerMetronome();
    await metronome.touchPlayerControllers(controller, _chewieController);
  }

  @override
  void initState() {
    super.initState();
    notifier = Provider.of<PlayerNotifier>(context, listen: false);
    var metronome = VideoPlayerMetronome();
    metronome.speedUp = false;
    metronome.addTicker(this);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
        context,
        chewieController.videoPlayerController.value.errorDescription!,
      ) ?? const Center(
        child: Icon(
          Icons.error,
          color: Colors.white,
          size: 42,
        ),
      );
    }
    Widget controls = Stack(
      children: [
        if (_displayBufferingIndicator)
          const Center(
            child: CircularProgressIndicator(),
          )
        else
          _buildHitArea(),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (_subtitleOn)
              Transform.translate(
                offset: Offset(
                  0.0,
                  notifier.hideStuff ? barHeight * 0.8 : 0.0,
                ),
                child:
                _buildSubtitles(context, chewieController.subtitle!),
              ),
            _buildBottomBar(context),
          ],
        ),
      ],
    );
    controls = Focus(
      focusNode: _focusNode,
      child: controls,
      onKeyEvent: (focusNode, event) => _keyEvent(event),
    );
    var metronome = VideoPlayerMetronome();
    return MouseRegion(
      onHover: (_) {
        _cancelAndRestartTimer();
      },
      child: GestureDetector(
        onTapDown: (details) {
          metronome.speedUp = true;
          _hideTimer?.cancel();
        },
        onTapUp: (details) {
          metronome.speedUp = false;
          _cancelAndRestartTimer();
        },
        onTapCancel: () {
          metronome.speedUp = false;
          _cancelAndRestartTimer();
        },
        onTap: () {
          metronome.speedUp = false;
          _cancelAndRestartTimer();
        },
        onDoubleTap: () {
          _playPause();
        },
        child: AbsorbPointer(
          absorbing: notifier.hideStuff,
          child: controls,
        ),
      ),
    );
  }

  KeyEventResult _keyEvent(KeyEvent event) {
    logInfo('key event: $event');
    _cancelAndRestartTimer();
    var checker = RawKeyboardChecker();
    var key = checker.checkKeyEvent(event);
    logInfo('key: $key');
    if (key == null) {
      return KeyEventResult.ignored;
    } else if (key == RawKeyboardKey.arrowUp) {
      logInfo('volume up');
      volumeUp();
    } else if (key == RawKeyboardKey.arrowDown) {
      logInfo('volume down');
      volumeDown();
    } else if (key == RawKeyboardKey.arrowLeft) {
      logInfo('seek backward');
      seekBackward();
    } else if (key == RawKeyboardKey.arrowRight) {
      logInfo('seek forward');
      seekForward();
    } else if (key == RawKeyboardKey.enter || key == RawKeyboardKey.space) {
      logInfo('play/pause');
      _playPause();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _changePosition({int seconds = 0}) async {
    var position = await controller.position;
    if (position == null) {
      return;
    } else if (_chewieController?.isLive == true) {
      logInfo('live video cannot seek position');
      return;
    }
    await controller.seekTo(position + Duration(seconds: seconds));
  }
  Future<void> seekForward() async => await _changePosition(seconds: 15);
  Future<void> seekBackward() async => await _changePosition(seconds: -15);

  Future<void> _changeVolume({required double delta}) async {
    var volume = controller.value.volume + delta;
    if (volume > 1.0) {
      volume = 1.0;
    } else if (volume < 0.0) {
      volume = 0.0;
    }
    await controller.setVolume(volume);
  }
  Future<void> volumeUp() async => await _changeVolume(delta: 0.1);
  Future<void> volumeDown() async => await _changeVolume(delta: -0.1);

  @override
  void dispose() {
    var metronome = VideoPlayerMetronome();
    metronome.removeTicker(this);
    _dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildSubtitles(BuildContext context, Subtitles subtitles) {
    if (!_subtitleOn) {
      return const SizedBox();
    }
    final currentSubtitle = subtitles.getByPosition(_subtitlesPosition);
    if (currentSubtitle.isEmpty) {
      return const SizedBox();
    }

    if (chewieController.subtitleBuilder != null) {
      return chewieController.subtitleBuilder!(
        context,
        currentSubtitle.first!.text,
      );
    }

    return Padding(
      padding: EdgeInsets.all(marginSize),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0x96000000),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          currentSubtitle.first!.text.toString(),
          style: const TextStyle(
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  AnimatedOpacity _buildBottomBar(
      BuildContext context,
      ) {
    // final iconColor = Theme.of(context).textTheme.labelLarge!.color;
    var iconColor = Colors.white;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: barHeight + (chewieController.isFullScreen ? 10.0 : 0),
        padding: EdgeInsets.only(
          left: 20,
          bottom: !chewieController.isFullScreen ? 10.0 : 0,
        ),
        child: SafeArea(
          bottom: chewieController.isFullScreen,
          minimum: chewieController.controlsSafeAreaMinimum,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (chewieController.isLive)
                      Expanded(child: Text('LIVE',
                        style: TextStyle(
                          color: iconColor,
                          decoration: TextDecoration.none,
                        ),
                      ))
                    else
                      _buildPosition(iconColor),
                    if (chewieController.allowMuting)
                      _buildMuteButton(controller, iconColor),
                    const Spacer(),
                    if (!chewieController.isLive)
                      _buildSpeedButton(controller, iconColor, barHeight),
                    if (chewieController.allowFullScreen)
                      _buildExpandButton(iconColor),
                  ],
                ),
              ),
              SizedBox(
                height: chewieController.isFullScreen ? 15.0 : 0,
              ),
              if (!chewieController.isLive)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      children: [
                        _buildProgressBar(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(
      VideoPlayerController controller,
      Color? iconColor,
      ) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();

        if (_latestValue.volume == 0) {
          controller.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRect(
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.only(
              left: 6.0,
            ),
            child: Icon(
              _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildSpeedButton(
      VideoPlayerController controller,
      Color? iconColor,
      double barHeight,
      ) {
    var metronome = VideoPlayerMetronome();
    double playbackSpeed = metronome.getPlaybackSpeed(chewieController.isLive);
    bool speedUp = metronome.speedUp;
    String text = speedUp ? '>> X$playbackSpeed' : 'X$playbackSpeed';
    Color? color = speedUp ? Colors.red : iconColor;
    return GestureDetector(
      onTap: () => setState(() {
        metronome.changePlaybackSpeed();
        metronome.setPlaybackSpeed(controller, chewieController.isLive);
      }),
      child: Container(
        alignment: Alignment.center,
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.only(
          left: 6.0,
          right: 8.0,
        ),
        child: Text(text,
          style: TextStyle(
            fontSize: 16,
            color: color,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  GestureDetector _buildExpandButton(Color? iconColor) {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight + (chewieController.isFullScreen ? 15.0 : 0),
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          child: Center(
            child: Icon(
              chewieController.isFullScreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    final bool isFinished = _latestValue.position >= _latestValue.duration;
    final bool showPlayButton = !_dragging && !notifier.hideStuff;

    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          if (_displayTapped) {
            setState(() {
              notifier.hideStuff = true;
            });
          } else {
            _cancelAndRestartTimer();
          }
        } else {
          _playPause();

          setState(() {
            notifier.hideStuff = true;
          });
        }
      },
      child: CenterPlayButton(
        backgroundColor: Colors.black54,
        iconColor: Colors.white,
        isFinished: isFinished,
        isPlaying: controller.value.isPlaying,
        show: showPlayButton,
        onPressed: _playPause,
      ),
    );
  }

  Widget _buildPosition(Color? iconColor) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;

    return RichText(
      text: TextSpan(
        text: '${formatDuration(position)} ',
        children: <InlineSpan>[
          TextSpan(
            text: '/ ${formatDuration(duration)}',
            style: TextStyle(
              fontSize: 14.0,
              color: iconColor?.withOpacity(.75),
              fontWeight: FontWeight.normal,
            ),
          )
        ],
        style: TextStyle(
          fontSize: 14.0,
          color: iconColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      notifier.hideStuff = false;
      _displayTapped = true;
    });
  }

  Future<void> _initialize() async {
    _subtitleOn = chewieController.subtitle?.isNotEmpty ?? false;
    controller.addListener(_updateState);

    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            notifier.hideStuff = false;
          });
        }
      });
    }
  }

  void _onExpandCollapse() {
    setState(() {
      notifier.hideStuff = true;

      chewieController.toggleFullScreen();
      _showAfterExpandCollapseTimer = Timer(
        const Duration(milliseconds: 300),
        _cancelAndRestartTimer,
      );
    });
  }

  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        notifier.hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        _cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          if (isFinished) {
            controller.seekTo(Duration.zero);
          }
          controller.play();
        }
      }
    });
  }

  void _startHideTimer() {
    final hideControlsTimer = chewieController.hideControlsTimer.isNegative
        ? ChewieController.defaultHideControlsTimer
        : chewieController.hideControlsTimer;
    _hideTimer = Timer(hideControlsTimer, () {
      if (mounted) {
        setState(() {
          notifier.hideStuff = true;
        });
      }
    });
  }

  void _bufferingTimerTimeout() {
    _displayBufferingIndicator = true;
    if (mounted) {
      setState(() {});
    }
  }

  void _updateState() {
    if (!mounted) return;

    // display the progress bar indicator only after the buffering delay if it has been set
    if (chewieController.progressIndicatorDelay != null) {
      if (controller.value.isBuffering) {
        _bufferingDisplayTimer ??= Timer(
          chewieController.progressIndicatorDelay!,
          _bufferingTimerTimeout,
        );
      } else {
        _bufferingDisplayTimer?.cancel();
        _bufferingDisplayTimer = null;
        _displayBufferingIndicator = false;
      }
    } else {
      _displayBufferingIndicator = _checkBuffering(controller);
      // _displayBufferingIndicator = controller.value.isBuffering;
    }

    setState(() {
      _latestValue = controller.value;
      _subtitlesPosition = controller.value.position;
    });
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: MaterialVideoProgressBar(
        controller,
        onDragStart: () {
          setState(() {
            _dragging = true;
          });

          _hideTimer?.cancel();
        },
        onDragUpdate: () {
          _hideTimer?.cancel();
        },
        onDragEnd: () {
          setState(() {
            _dragging = false;
          });

          _startHideTimer();
        },
        colors: chewieController.materialProgressColors ??
            ChewieProgressColors(
              playedColor: Theme.of(context).colorScheme.secondary,
              handleColor: Theme.of(context).colorScheme.secondary,
              bufferedColor:
              Theme.of(context).colorScheme.background.withOpacity(0.5),
              backgroundColor: Theme.of(context).disabledColor.withOpacity(.5),
            ),
      ),
    );
  }

}

bool _checkBuffering(VideoPlayerController controller) {
  //
  //  check control value
  //
  if (!controller.value.isBuffering) {
    // not buffering
    return false;
  }
  //
  //  check position in buffered ranges
  //
  final position = controller.value.position;
  final buffered = controller.value.buffered;
  final current = buffered.firstWhere(
        (range) => range.start <= position && position <= range.end,
    orElse: () => _zeroRange,
  );
  if (current == _zeroRange) {
    // buffered empty?
    // it is buffering
    return true;
  }
  // check current range
  final end = current.end - _safeDistance;
  if (position < end) {
    // current position is far enough from the end,
    // set the status to 'not buffering'
    return false;
  }
  // search for next range
  for (var item in buffered) {
    if (item.start == current.end) {
      // next buffered range got
      // set the status to 'not buffering'
      return false;
    }
  }
  // current position is near the end of currant range,
  // and next range not found,
  // it is buffering
  return true;
}

final _zeroRange = DurationRange(Duration.zero, Duration.zero);
const _safeDistance = Duration(seconds: 8);
