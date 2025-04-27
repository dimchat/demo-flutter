import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;

import '../channels/manager.dart';
import '../common/constants.dart';
import '../ui/styles.dart';

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

  Color? _color(BuildContext context) {
    if (!_recording) {
      return Styles.colors.recorderBackgroundColor;
    } else if (_position.dy > 0.0) {
      return Styles.colors.recordingBackgroundColor;
    } else {
      return Styles.colors.cancelRecordingBackgroundColor;
    }
  }
  String get _text {
    if (!_recording) {
      return 'Hold to Talk'.tr;
    } else if (_position.dy < 0) {
      return 'Release to Cancel'.tr;
    } else {
      return 'Release to Send'.tr;
    }
  }

  Widget _button(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: _color(context),
    ),
    alignment: Alignment.center,
    child: Text(_text, textAlign: TextAlign.center,
      style: TextStyle(
        color: Styles.colors.recorderTextColor,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: GestureDetector(
      child: _button(context),
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
        PermissionCenter().requestMicrophonePermissions(context, onGranted: (context) {
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
      onLongPressUp: () {
        Log.warning('tap up');
        setState(() {
          _recording = false;
        });
        ChannelManager man = ChannelManager();
        man.audioChannel.stopRecord();
        Log.debug('stop record, touch point: $_position');
      },
    ),
  );

}
