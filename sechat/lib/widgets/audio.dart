import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../client/filesys/paths.dart';
import '../client/http/ftp.dart';
import 'permissions.dart';

typedef OnVoiceRecordComplected = void Function(String path, double duration);

/// RecordButton
class RecordButton extends StatefulWidget {
  const RecordButton(this.identifier, {required this.onComplected, super.key});

  final ID identifier;
  final OnVoiceRecordComplected onComplected;

  @override
  State<StatefulWidget> createState() => _RecordState();

}

class _RecordState extends State<RecordButton> {

  bool _recording = false;

  int _startTime = 0;

  Offset _position = Offset.zero;

  Color? get _color {
    if (!_recording) {
      return null;
    } else if (_position.dy < 0.0) {
      return Colors.grey.shade100;
    } else {
      return Colors.lightGreen.shade100;
    }
  }
  String get _text {
    if (!_recording) {
      return 'Press and record';
    } else if (_position.dy < 0) {
      return 'Release to cancel';
    } else {
      return 'Release to send out';
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    // color: _color,
    child: GestureDetector(
      child: Container(
        color: _color,
        alignment: Alignment.center,
        child: Text(_text, textAlign: TextAlign.center),
      ),
      onLongPressDown: (details) {
        Log.warning('tap down: ${details.localPosition}');
        setState(() {
          _position = details.localPosition;
          _recording = true;
        });
      },
      onLongPressCancel: () {
        Log.warning('tap cancel');
        setState(() {
          _recording = false;
        });
      },
      onLongPressStart: (details) {
        Log.debug('check permissions');
        requestSecondaryPermissions(context, onGranted: (context) {
          Log.debug('start record');
          _AudioRecorder recorder = _AudioRecorder();
          recorder.startRecord();
          _startTime = Time.currentTimeMillis;
        });
      },
      onLongPressMoveUpdate: (details) {
        // Log.warning('move: ${details.localPosition}');
        setState(() {
          _position = details.localPosition;
        });
      },
      onLongPressUp: () async {
        Log.warning('tap up');
        if (mounted) {
          setState(() {
            _recording = false;
          });
        }
        int now = Time.currentTimeMillis;
        _AudioRecorder recorder = _AudioRecorder();
        String? path = await recorder.stopRecord();
        if (path != null && _position.dy > 0.0) {
          double duration = (now - _startTime) / 1000.0;
          Log.debug('stop record and send out: $_position, $duration, $path');
          widget.onComplected(path, duration);
        } else {
          Log.debug('stop record: $_position, $path');
        }
      },
    ),
  );

}

class _AudioRecorder {
  factory _AudioRecorder() => _instance;
  static final _AudioRecorder _instance = _AudioRecorder._internal();
  _AudioRecorder._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  final String _filename = 'voice.mp4';

  Future<void> startRecord() async {
    // remove old file
    await Paths.delete(_filename);

    // check and stop the current recorder first
    await stopRecord();

    Log.warning('opening recorder');
    await _recorder.openRecorder();
    Log.warning('start recording: $_filename');
    await _recorder.startRecorder(toFile: _filename, codec: Codec.aacMP4);
  }

  Future<String?> stopRecord() async {
    String? path;
    if (_recorder.isRecording || _recorder.isPaused) {
      path = await _recorder.stopRecorder();
      Log.warning('stopped recording: $path');
    }
    await _recorder.closeRecorder();
    Log.warning('closed recorder');
    return path;
  }

}

class _AudioPlayer {
  factory _AudioPlayer() => _instance;
  static final _AudioPlayer _instance = _AudioPlayer._internal();
  _AudioPlayer._internal();

  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  Future<void> startPlay(String path, TWhenFinished whenFinished) async {
    if (await Paths.exists(path)) {
      Log.debug('playing audio: $path');
    } else {
      Log.error('file not exists: $path');
      return;
    }
    // check and stop the current player first
    await stopPlay();

    if (_player.isOpen()) {
      // _player.setSubscriptionDuration(const Duration(milliseconds: 10));
      await _player.setVolume(1.0);
    } else {
      Log.debug('opening player: $path');
      await _player.openPlayer();
    }
    Log.warning('start playing: $path');
    await _player.startPlayer(fromURI: path, codec: Codec.aacMP4, whenFinished: () {
      stopPlay();
      whenFinished();
    });
  }

  Future<void> stopPlay() async {
    Log.warning('stop playing');
    if (_player.isPlaying || _player.isPaused) {
      Log.debug('stopping player');
      await _player.stopPlayer();
    }
    if (_player.isOpen()) {
      Log.debug('closing player');
      await _player.closePlayer();
    }
  }

}

/// AudioView
class AudioContentView extends StatefulWidget {
  const AudioContentView(this.content, {this.color, super.key});

  final AudioContent content;
  final Color? color;

  @override
  State<StatefulWidget> createState() => _AudioContentState();

}

class _AudioContentState extends State<AudioContentView> {

  late final double _duration;
  String? _path;

  bool _playing = false;

  Future<void> _reload() async {
    FileTransfer ftp = FileTransfer();
    _path = await ftp.getFilePath(widget.content);
    if (_path == null) {
      Log.error('failed to get audio path');
      return;
    }
  }

  void _togglePlay() {
    _AudioPlayer player = _AudioPlayer();
    String? path = _path;
    bool playing = _playing;
    if (playing) {
      player.stopPlay();
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
    } else if (path != null) {
      if (mounted) {
        setState(() {
          _playing = true;
        });
      }
      player.startPlay(path, () {
        if (mounted) {
          setState(() {
            _playing = false;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _duration = widget.content.getDouble('duration') ?? 0;
    _reload();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    color: widget.color,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: GestureDetector(
      onTap: () {
        setState(() => _togglePlay());
      },
      child: Row(
        children: [
          _playing ? const Icon(CupertinoIcons.volume_up) : const Icon(CupertinoIcons.play),
          Expanded(
            flex: 1,
            child: Text('${_duration.toStringAsFixed(3)}"',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );

}
