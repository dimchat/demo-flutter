/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
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
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:lnc/lnc.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:dim_client/dim_common.dart';

import '../ui/icons.dart';
import '../widgets/alert.dart';
import '../widgets/permissions.dart';

import 'image.dart';
import 'loader.dart';


/// preview avatar image
void previewImage(BuildContext ctx, PortableNetworkFile pnf) {
  showCupertinoDialog(
    context: ctx,
    builder: (context) => _ImagePreview(_PreviewInfo([pnf], 0)),
  );
}

/// preview image in chat box
void previewImageContent(BuildContext ctx, ImageContent content, List<InstantMessage> messages) =>
    _fetchImages(messages, content).then((info) {
      showCupertinoDialog(
        context: ctx,
        builder: (context) => _ImagePreview(info),
      );
    });

class _ImagePreview extends StatefulWidget {
  const _ImagePreview(this.info);

  final _PreviewInfo info;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {

  PageController? _controller;

  PageController get controller {
    PageController? ctrl = _controller;
    if (ctrl == null) {
      ctrl = PageController(initialPage: widget.info.index);
      _controller = ctrl;
    }
    return ctrl;
  }

  @override
  Widget build(BuildContext context) => Container(
    color: CupertinoColors.black,
    child: _gallery(),
  );

  Widget _gallery() => PhotoViewGallery.builder(
    scrollPhysics: const BouncingScrollPhysics(),
    builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
      child: GestureDetector(
        child: NetworkImageFactory().getImageView(widget.info.images[index]),
        onTap: () {
          Navigator.pop(context);
        },
        onLongPress: () {
          Alert.actionSheet(context, null, null,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(AppIcons.saveFileIcon),
                const SizedBox(width: 12,),
                Text('Save to Album'.tr),
              ],
            ), () => requestPhotosPermissions(context,
              onGranted: (context) => _confirmToSave(context, widget.info.images[index]),
            ),
          );
        },
      ),
    ),
    itemCount: widget.info.images.length,
    backgroundDecoration: const BoxDecoration(color: CupertinoColors.black),
    pageController: controller,
  );

}

void _confirmToSave(BuildContext context, PortableNetworkFile pnf) =>
    Alert.confirm(context, 'Confirm',
      'Sure to save this image?'.tr,
      okAction: () => _saveImage(context, pnf),
    );
void _saveImage(BuildContext context, PortableNetworkFile pnf) {
  PortableNetworkLoader loader = NetworkImageFactory().getImageLoader(pnf);
  loader.run().then((ok) {
    assert(ok && loader.status == PortableNetworkStatus.success, 'PNF loader error');
    loader.cacheFilePath.then((path) {
      if (path == null) {
        Alert.show(context, 'Error', 'Failed to get image file');
      } else {
        _saveFile(context, path);
      }
    });
  });
}
void _saveFile(BuildContext context, String path) =>
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

class _PreviewInfo {
  _PreviewInfo(this.images, this.index);

  List<PortableNetworkFile> images;
  int index;

}

Future<_PreviewInfo> _fetchImages(List<InstantMessage> messages, ImageContent target) async {
  int pos = messages.length;
  Content content;
  PortableNetworkFile? pnf;
  List<PortableNetworkFile> images = [];
  int index = -1;
  while (--pos >= 0) {
    content = messages[pos].content;
    if (content is! ImageContent) {
      continue;
    } else if (content == target) {
      assert(index == -1, 'duplicated message?');
      index = images.length;
    }
    pnf = PortableNetworkFile.parse(content);
    if (pnf == null) {
      assert(false, '[PNF] image content error: $content');
      continue;
    }
    images.add(pnf);
  }
  assert(images.length > index, 'index error: $index, ${images.length}');
  return _PreviewInfo(images, index);
}
