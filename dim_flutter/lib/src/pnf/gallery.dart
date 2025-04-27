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
import 'package:photo_view/photo_view_gallery.dart';

import 'package:dim_client/ok.dart';
import 'package:pnf/pnf.dart';

import '../ui/icons.dart';
import '../ui/nav.dart';
import '../widgets/alert.dart';
import '../widgets/permissions.dart';

import 'image.dart';
import 'net_image.dart';


class Gallery {
  Gallery(this.images, this.index);

  final List<PortableImageView> images;
  final int index;

  void show(BuildContext context) => showPage(
    context: context,
    builder: (context) => _ImagePreview(this),
  );

  static void saveImage(BuildContext context, PortableImageLoader loader) =>
      PermissionCenter().requestPhotoAccessingPermissions(context,
        onGranted: (context) => _confirmToSave(context, loader),
      );

  static Image? getThumbnail(Map content) {
    String? small = content['thumbnail'];
    return small == null ? null : ImageUtils.getImage(small);
  }
  static Image? getSnapshot(Map content) {
    String? small = content['snapshot'];
    return small == null ? null : ImageUtils.getImage(small);
  }

  static ImageProvider? getThumbnailProvider(Map content) {
    String? small = content['thumbnail'];
    return small == null ? null : ImageUtils.getProvider(small);
  }
  static ImageProvider? getSnapshotProvider(Map content) {
    String? small = content['snapshot'];
    return small == null ? null : ImageUtils.getProvider(small);
  }

}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview(this.info);

  final Gallery info;

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
  Widget build(BuildContext context) => GestureDetector(
    child: Container(
      color: CupertinoColors.black,
      child: _gallery(),
    ),
    onTap: () => closePage(context),
  );

  Widget _gallery() => PhotoViewGallery.builder(
    scrollPhysics: const BouncingScrollPhysics(),
    builder: (context, index) {
      var view = widget.info.images[index];
      var loader = view.loader as PortableImageLoader;
      return PhotoViewGalleryPageOptions.customChild(
        child: GestureDetector(
          child: view,
          // onTap: () => closePage(context),
          onLongPress: () => Alert.actionSheet(context, null, null,
            Alert.action(AppIcons.saveFileIcon, 'Save to Album'),
                () => Gallery.saveImage(context, loader),
          ),
        ),
      );
    },
    itemCount: widget.info.images.length,
    backgroundDecoration: const BoxDecoration(color: CupertinoColors.black),
    pageController: controller,
  );

}

void _confirmToSave(BuildContext context, PortableImageLoader loader) {
  Alert.confirm(context, 'Confirm',
    'Sure to save this image?'.tr,
    okAction: () => _saveImage(context, loader),
  );
}
void _saveImage(BuildContext context, PortableImageLoader loader) {
  if (loader.status == PortableNetworkStatus.success) {
    loader.cacheFilePath.then((path) {
      if (!context.mounted) {
        Log.warning('context unmounted: $context');
      } else if (path == null) {
        Alert.show(context, 'Error', 'Failed to get image file'.tr);
      } else {
        _saveFile(context, path);
      }
    });
  } else {
    Alert.show(context, 'Error', 'Cannot save this image'.tr);
  }
}
void _saveFile(BuildContext context, String path) {
  ImageGallerySaver.saveFile(path).then((result) {
    Log.info('saving image: $path, result: $result');
    if (!context.mounted) {
      Log.warning('context unmounted: $context');
    } else if (result != null && result['isSuccess']) {
      Alert.show(context, 'Success', 'Image saved to album'.tr);
    } else {
      String? error = result['error'];
      error ??= result['errorMessage'];
      error ??= 'Failed to save image to album'.tr;
      Alert.show(context, 'Error', error);
    }
  });
}
