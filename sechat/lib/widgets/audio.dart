import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../client/http/ftp.dart';

/// RecordButton
class RecordButton extends StatefulWidget {
  const RecordButton(this.identifier, {super.key});

  final ID identifier;

  @override
  State<StatefulWidget> createState() => _RecordState();

}

class _RecordState extends State<RecordButton> {

  bool _recording = false;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    // color: _recording ? Colors.lightGreen.shade100 : null,
    child: GestureDetector(
      child: Container(
        color: _recording ? Colors.lightGreen.shade100 : null,
        alignment: Alignment.center,
        child: Text(_recording ? 'Release to send out' : 'Press and record',
          textAlign: TextAlign.center,
        ),
      ),
      onTapDown: (details) {
        Log.warning('tap down: $details');
        setState(() {
          _recording = true;
        });
      },
      onTapUp: (details) {
        Log.warning('tap up: $details');
        setState(() {
          _recording = false;
        });
      },
      onTapCancel: () {
        Log.warning('tap cancel');
        setState(() {
          _recording = false;
        });
      },
    ),
  );

}

void startAudioRecorder(BuildContext context) {
  Log.warning('starting recorder');
}

String? stopAudioRecorder(BuildContext context) {
  Log.warning('recorder stopped');
  return null;
}

/// AudioView
class AudioContentView extends StatefulWidget {
  const AudioContentView(this.content, {this.color, this.padding, super.key});

  final AudioContent content;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  State<StatefulWidget> createState() => _AudioContentState();

}

class _AudioContentState extends State<AudioContentView> {

  late final double _duration;
  String? _path;

  bool _playing = false;

  void _reload() {
    FileTransfer ftp = FileTransfer();
    ftp.getFilePath(widget.content).then((path) {
      if (path == null) {
        Log.error('failed to get audio path');
        return;
      }
      _path = path;
    });
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
    padding: widget.padding,
    child: GestureDetector(
      onTap: () {
        setState(() {
          _playing = !_playing;
        });
        Log.warning('audio playing: $_playing');
      },
      child: Row(
        children: [
          _playing ? const Icon(CupertinoIcons.volume_up) : const Icon(CupertinoIcons.play),
          Container(
            width: 128,
            // color: Colors.lightGreen,
            alignment: Alignment.center,
            child: Text('${_duration.toStringAsFixed(3)}"'),
          ),
        ],
      ),
    ),
  );

}
