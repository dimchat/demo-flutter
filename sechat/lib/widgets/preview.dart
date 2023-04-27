import 'dart:io';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../client/http/ftp.dart';

void previewImageContent(BuildContext ctx, ImageContent content, List<InstantMessage> messages) {
  FileTransfer ftp = FileTransfer();
  ftp.getFilePath(content).then((path) {
    if (path == null) {
      Log.error('failed to get image path: $content');
    } else {
      showCupertinoDialog(
        context: ctx,
        builder: (context) => _ImagePreview(messages, _PreviewInfo([path], 0)),
      );
    }
  }).onError((error, stackTrace) {
    Log.error('failed to get image path: $content');
  });
}

class _PreviewInfo {
  _PreviewInfo(this.images, this.index);

  List<String> images;
  int index;
}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview(this.messages, this.info);

  final List<InstantMessage> messages;
  final _PreviewInfo info;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {

  PageController? _controller;

  PageController get controller {
    PageController? ctrl = _controller;
    if (ctrl == null) {
      ctrl = PageController(initialPage: info.index);
      _controller = ctrl;
    }
    return ctrl;
  }

  _PreviewInfo get info => widget.info;

  Future<void> _reload() async {
    String path = info.images[info.index];
    List<String> images = await _allImages(widget.messages);
    int index = images.indexOf(path);
    if (index < 0) {
      index = images.length - 1;
    }
    if (mounted) {
      setState(() {
        info.images = images;
        info.index = index;
        controller.jumpToPage(index);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: CupertinoColors.black,
    child: PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (context, index) => PhotoViewGalleryPageOptions(
        imageProvider: FileImage(File(info.images[index])),
        minScale: 0.5,
        onScaleEnd: (context, details, controllerValue) {
          double? scale = controllerValue.scale;
          if (scale != null && scale < 0.2) {
            Navigator.pop(context);
          }
        },
      ),
      itemCount: info.images.length,
      backgroundDecoration: const BoxDecoration(color: CupertinoColors.black),
      pageController: controller,
    ),
  );
}

Future<List<String>> _allImages(List<InstantMessage> messages) async {
  FileTransfer ftp = FileTransfer();
  int pos = messages.length;
  Content content;
  String? path;
  List<String> images = [];
  while (--pos >= 0) {
    content = messages[pos].content;
    if (content is ImageContent) {
      path = await ftp.getFilePath(content);
      if (path != null) {
        images.add(path);
      }
    }
  }
  return images;
}
