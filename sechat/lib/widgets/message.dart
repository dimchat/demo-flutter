import 'dart:io';
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/material.dart';
import 'package:sechat/client/shared.dart';

import '../client/http/ftp.dart';

/// ImageView
class ImageContentView extends StatefulWidget {
  const ImageContentView(this.content, {this.color, this.padding, super.key});

  final ImageContent content;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  State<StatefulWidget> createState() => _ImageContentState();

}

class _ImageContentState extends State<ImageContentView> {

  Widget? _image;

  void _reload() {
    FileTransfer ftp = FileTransfer();
    ftp.getFilePath(widget.content).then((path) {
      if (path == null) {
        Log.error('failed to get image path');
        return;
      }
      if (mounted) {
        setState(() {
          _image = Image.file(File(path));
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Uint8List? bytes = widget.content.thumbnail;
    if (bytes != null) {
      _image = Image.memory(bytes);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    Widget? img = _image;
    if (img != null) {
      return img;
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
  const NameView(this.identifier, this.style, {super.key});

  final ID identifier;
  final TextStyle? style;

  static NameView fromID(ID identifier, {required TextStyle? style}) =>
      NameView(identifier, style);

  @override
  State<StatefulWidget> createState() => _NameState();

}

class _NameState extends State<NameView> {

  String? _name;

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
