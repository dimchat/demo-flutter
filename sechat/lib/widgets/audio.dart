import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../channels/manager.dart';
import '../client/constants.dart';
import '../network/ftp.dart';
import '../views/styles.dart';
import 'permissions.dart';

typedef OnVoiceRecordComplected = void Function(Uint8List mp4, double duration);

/// RecordButton
class RecordButton extends StatefulWidget {
  const RecordButton({required this.onComplected, super.key});

  final OnVoiceRecordComplected onComplected;

  @override
  State<StatefulWidget> createState() => _RecordState();

}

class _RecordState extends State<RecordButton> implements lnc.Observer {
  _RecordState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kRecordFinished);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kRecordFinished);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kRecordFinished) {
      Uint8List data = info?['data'];
      double duration = info?['duration'];
      if (_position.dy > 0.0) {
        Log.debug('stop record, send: $_position, ${duration}s, ${data.length} bytes');
        widget.onComplected(data, duration);
      } else {
        Log.debug('stop record, cancel: $_position, ${duration}s, ${data.length} bytes');
      }
    }
  }

  bool _recording = false;

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
          ChannelManager man = ChannelManager();
          man.audioChannel.startRecord();
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
        ChannelManager man = ChannelManager();
        man.audioChannel.stopRecord();
        Log.debug('stop record, touch point: $_position');
      },
    ),
  );

}

/// AudioView
class AudioContentView extends StatefulWidget {
  const AudioContentView(this.content, {this.color, super.key});

  final AudioContent content;
  final Color? color;

  @override
  State<StatefulWidget> createState() => _AudioContentState();

}

class _AudioContentState extends State<AudioContentView> implements lnc.Observer {
  _AudioContentState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPlayFinished);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kPlayFinished);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    if (name == NotificationNames.kPlayFinished) {
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
    }
  }

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
    ChannelManager man = ChannelManager();
    String? path = _path;
    bool playing = _playing;
    if (playing) {
      man.audioChannel.stopPlay(_path);
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
      man.audioChannel.startPlay(path);
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
    padding: Styles.audioMessagePadding,
    child: GestureDetector(
      onTap: () {
        setState(() => _togglePlay());
      },
      child: Row(
        children: [
          _playing ? const Icon(Styles.playingAudioIcon) : const Icon(Styles.playAudioIcon),
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
