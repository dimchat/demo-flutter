import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/http/ftp.dart';
import '../client/shared.dart';

/// ImageView
class ImageContentView extends StatefulWidget {
  const ImageContentView(this.content, {this.color, this.padding, this.onTap, super.key});

  final ImageContent content;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  final VoidCallback? onTap;

  @override
  State<StatefulWidget> createState() => _ImageContentState();

}

class _ImageContentState extends State<ImageContentView> {

  String? _path;

  void _reload() {
    FileTransfer ftp = FileTransfer();
    ftp.getFilePath(widget.content).then((path) {
      if (path == null) {
        Log.error('failed to get image path');
        return;
      }
      if (mounted) {
        setState(() {
          _path = path;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    String? path = _path;
    if (path != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Image.file(File(path)),
      );
    }
    Uint8List? bytes = widget.content.thumbnail;
    if (bytes != null) {
      return Image.memory(bytes);
    }
    return Container(
      color: widget.color,
      padding: widget.padding,
      child: const Text('Image error'),
    );
  }

}

/// NameView
class NameView extends StatefulWidget {
  const NameView(this.identifier, {required this.style, super.key});

  final ID identifier;
  final TextStyle? style;

  @override
  State<StatefulWidget> createState() => _NameState();

}

class _NameState extends State<NameView> implements lnc.Observer {
  _NameState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  String? _name;

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    assert(name == NotificationNames.kDocumentUpdated, 'notification error: $notification');
    ID? identifier = info?['ID'];
    if (identifier == null) {
      Log.error('notification error: $notification');
    } else if (identifier == widget.identifier) {
      _reload();
    }
  }

  void _reload() {
    GlobalVariable shared = GlobalVariable();
    shared.facebook.getName(widget.identifier).then((name) {
      if (mounted) {
        setState(() {
          _name = name;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _name = widget.identifier.toString();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Text('$_name', style: widget.style);

}
