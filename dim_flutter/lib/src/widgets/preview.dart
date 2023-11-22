import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../network/ftp.dart';
import '../ui/icons.dart';

import 'alert.dart';
import 'permissions.dart';

/// preview avatar image
void previewImage(BuildContext ctx, String path) {
  showCupertinoDialog(
    context: ctx,
    builder: (context) => _ImagePreview(const [], null, _PreviewInfo([path], 0)),
  );
}

/// preview image in chat box
void previewImageContent(BuildContext ctx, ImageContent content, List<InstantMessage> messages) {
  FileTransfer ftp = FileTransfer();
  ftp.getFilePath(content).then((path) {
    if (path == null) {
      Log.error('failed to get image path: $content');
    } else {
      showCupertinoDialog(
        context: ctx,
        builder: (context) => _ImagePreview(messages, content, _PreviewInfo([path], 0)),
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
  const _ImagePreview(this.messages, this.content, this.info);

  final List<InstantMessage> messages;
  final ImageContent? content;
  final _PreviewInfo info;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {

  PageController? _controller;
  Offset? _position;

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
    ImageContent? content = widget.content;
    if (content == null) {
      // avatar image
      return;
    }
    String path = info.images[info.index];
    var pair = await _fetchImages(widget.messages, content);
    List<String> images = pair.first;
    int index = pair.second;
    if (index < 0) {
      assert(false, 'preview index error: ${images.length}');
      index = images.indexOf(path);
      if (index < 0) {
        index = images.length - 1;
      }
    } else if (index >= images.length) {
      assert(false, 'preview index error: $index, ${images.length}');
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
    child: _gallery(),
  );

  Widget _gallery() => PhotoViewGallery.builder(
    scrollPhysics: const BouncingScrollPhysics(),
    builder: (context, index) => PhotoViewGalleryPageOptions(
      imageProvider: FileImage(File(info.images[index])),
      // minScale: 0.5,
      // onScaleEnd: (context, details, controllerValue) {
      //   double? scale = controllerValue.scale;
      //   if (scale != null && scale < 0.2) {
      //     Navigator.pop(context);
      //   }
      // },
      onTapUp: (context, details, controllerValue) {
        Offset pos = details.localPosition;
        Offset? old = _position;
        if (old == null) {
          assert(false, 'should not happen');
        } else if (pos.dx == old.dx && pos.dy == old.dy) {
          // onTap();
          Navigator.pop(context);
        } else {
          Alert.actionSheet(context, null, null,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(AppIcons.saveFileIcon),
                const SizedBox(width: 12,),
                Text('Save to Album'.tr),
              ],
            ), () => requestPhotosPermissions(context,
              onGranted: (context) => _confirmToSave(context, info.images[index]),
            ),
          );
        }
      },
      onTapDown: (context, details, controllerValue) {
        _position = details.localPosition;
      },
    ),
    itemCount: info.images.length,
    backgroundDecoration: const BoxDecoration(color: CupertinoColors.black),
    pageController: controller,
  );

}

void _confirmToSave(BuildContext context, String path) =>
    Alert.confirm(context, 'Confirm',
      'Sure to save this image?'.tr,
      okAction: () => _saveImage(context, path),
    );
void _saveImage(BuildContext context, String path) =>
    ImageGallerySaver.saveFile(path).then((result) {
      Log.info('saving image: $path, result: $result');
      if (result != null && result['isSuccess']) {
        Alert.show(context, 'Success', 'Image saved to album'.tr);
      } else {
        String? error = result['error'];
        error ??= result['errorMessage'];
        error ??= 'Failed to save image to album'.tr;
        Alert.show(context, 'Error', error);
      }
    });

Future<Pair<List<String>, int>> _fetchImages(List<InstantMessage> messages, ImageContent target) async {
  FileTransfer ftp = FileTransfer();
  int pos = messages.length;
  Content content;
  String? path;
  List<String> images = [];
  int index = -1;
  while (--pos >= 0) {
    content = messages[pos].content;
    if (content is ImageContent) {
      path = await ftp.getFilePath(content);
      if (path != null) {
        if (content == target) {
          assert(index == -1, 'duplicated message?');
          index = images.length;
        }
        images.add(path);
      }
    }
  }
  return Pair(images, index);
}
