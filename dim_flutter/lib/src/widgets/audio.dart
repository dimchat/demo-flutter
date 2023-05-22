import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../channels/manager.dart';
import '../client/constants.dart';
import '../network/ftp.dart';
import 'permissions.dart';
import 'styles.dart';

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
        requestMicrophonePermissions(context, onGranted: (context) {
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
  AudioContentView(this.content, {this.color, super.key}) {
    // get file path
    Future.delayed(const Duration(milliseconds: 32))
        .then((value) => _reload());
  }

  final AudioContent content;
  final Color? color;

  final _AudioPlayInfo _info = _AudioPlayInfo();

  Future<void> _reload() async {
    FileTransfer ftp = FileTransfer();
    String? path = await ftp.getFilePath(content);
    if (path == null) {
      Log.debug('audio file not found: ${content.url}');
    } else {
      _info.path = path;
      await lnc.NotificationCenter().postNotification(kVoiceRefresh, this, {
        'content': content,
      });
    }
  }

  @override
  State<StatefulWidget> createState() => _AudioContentState();

}

const String kVoiceRefresh = 'VoiceRefresh';

class _AudioPlayInfo {
  String? path;
  bool playing = false;
}

class _AudioContentState extends State<AudioContentView> implements lnc.Observer {
  _AudioContentState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kFileDownloadSuccess);
    nc.addObserver(this, NotificationNames.kPlayFinished);
    nc.addObserver(this, kVoiceRefresh);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, kVoiceRefresh);
    nc.removeObserver(this, NotificationNames.kPlayFinished);
    nc.removeObserver(this, NotificationNames.kFileDownloadSuccess);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kPlayFinished) {
      String? path = userInfo?['path'];
      if (path != await _path) {
        return;
      }
      if (mounted) {
        setState(() {
          widget._info.playing = false;
        });
      }
    } else if (name == NotificationNames.kFileDownloadSuccess) {
      Uri? url = userInfo?['url'];
      String? path = userInfo?['path'];
      assert(url != null, 'download URL not found: $userInfo');
      if (url?.toString() == widget.content.url) {
        Log.info('audio file downloaded: $url => $path');
        if (path != null && mounted) {
          setState(() {
            widget._info.path = path;
          });
        }
      }
    } else if (name == kVoiceRefresh) {
      AudioContent? content = userInfo?['content'];
      if (mounted && identical(content, widget.content)) {
        setState(() {
          //
        });
      }
    }
  }

  Future<String?> get _path async {
    String? path = widget._info.path;
    if (path == null) {
      FileTransfer ftp = FileTransfer();
      path = await ftp.getFilePath(widget.content);
      widget._info.path = path;
    }
    return path;
  }

  String? get _duration {
    return widget.content.getDouble('duration')?.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    color: widget.color,
    padding: Styles.audioMessagePadding,
    child: GestureDetector(
      onTap: _togglePlay,
      child: Row(
        children: [
          _button(),
          Expanded(
            flex: 1,
            child: Text('${_duration ?? 0} s',
              textAlign: TextAlign.center,
              style: TextStyle(color: _color(), ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _togglePlay() async {
    ChannelManager man = ChannelManager();
    String? path = await _path;
    if (widget._info.playing) {
      await man.audioChannel.stopPlay(path);
      if (mounted) {
        setState(() {
          widget._info.playing = false;
        });
      }
    } else if (path != null) {
      if (mounted) {
        setState(() {
          widget._info.playing = true;
        });
      }
      await man.audioChannel.startPlay(path);
    }
  }

  Widget _button() => widget._info.path == null
      ? Icon(Styles.waitAudioIcon, color: _color(), ) : widget._info.playing
      ? const Icon(Styles.playingAudioIcon)
      : const Icon(Styles.playAudioIcon);

  Color? _color() => widget._info.path == null ? Colors.grey : null;

}
