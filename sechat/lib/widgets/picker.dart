import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lnc/lnc.dart';

import 'alert.dart';
import 'permissions.dart';

typedef OnImagePicked = void Function(String path);
typedef OnImageRead = void Function(String path, Uint8List data);

void openImagePicker(BuildContext context, {OnImagePicked? onPicked, required OnImageRead onRead}) =>
    Alert.actionSheet(context, null, null,
      'Camera', () => requestCameraPermissions(context,
        onGranted: (context) => _openImagePicker(context, true, onPicked, onRead),
      ),
      'Album', () => requestPhotosPermissions(context,
        onGranted: (context) => _openImagePicker(context, false, onPicked, onRead),
      ),
    );

void _openImagePicker(BuildContext context, bool camera, OnImagePicked? onPicked, OnImageRead onRead) =>
    ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery).then((file) {
      if (file == null) {
        Log.error('failed to get image file');
      } else {
        String path = file.path;
        if (onPicked != null) {
          onPicked(path);
        }
        file.readAsBytes().then((data) {
          Log.debug('image file length: ${data.length}, path: ${file.path}');
          onRead(path, data);
        }).onError((error, stackTrace) {
          Alert.show(context, 'Image File Error', '$error');
        });
      }
    }).onError((error, stackTrace) {
      String name = camera ? 'Camera' : 'Gallery';
      Alert.show(context, '$name Error', '$error');
    });


/// compress image for thumbnail (128*128) low quality
Future<Uint8List> compressThumbnail(Uint8List jpeg) async =>
    await FlutterImageCompress.compressWithList(jpeg,
      minHeight: 128,
      minWidth: 128,
      quality: 20,
    );


/// callback with small image data after resized down
void adjustImage(Uint8List jpeg, void Function(Uint8List small) onSank, {int width = 1024, int height = 1024}) =>
    _resolveImage(jpeg, (ui.Image image) async {
      _Size imgSize = _Size(image.width, image.height);
      _Size target = _Size(width, height);
      // check image size
      if (_needsResize(size: imgSize, target: target)) {
        // zoom out
        _Size size = _resizeDown(size: imgSize, target: target);
        Uint8List small = await FlutterImageCompress.compressWithList(jpeg,
          minWidth: size.width,
          minHeight: size.height,
        );
        Log.info('resized: $imgSize => $size; ${jpeg.length} => ${small.length} bytes');
        jpeg = small;
      } else {
        Log.info('no need to resize: $imgSize => $target');
      }
      onSank(jpeg);
    });

/// check whether image is too big to be resized
bool _needsResize({required _Size size, required _Size target}) {
  assert(target.width > 0 && target.height > 0, 'max size error: $target');
  if (size.width <= 0 || size.height <= 0) {
    assert(false, 'size error: $size');
    return false;
  }
  int sx = target.width;
  int sy = target.height;
  int mx = target.width + (target.width  >> 1);   // 1.5
  int my = target.height + (target.height >> 1);  // 1.5
  int lx = target.width << 1;   // 2.0
  int ly = target.height << 1;  // 2.0
  if (size.width <= sx && size.height <= sy) {
    // smaller than target size
    return false;
  } else if (size.width > lx || size.height > ly) {
    // too big than target size
    return true;
  }
  return (size.width >= sx && size.height > my)
      || (size.height >= sy && size.width > mx);
}

/// fetch size info from image data
void _resolveImage(Uint8List jpeg, void Function(ui.Image image) onResolved) =>
    MemoryImage(jpeg).resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) => onResolved(info.image))
    );

/// resize (width, height) to no larger than (maxWidth, maxHeight)
_Size _resizeDown({required _Size size, required _Size target}) {
  if (size.width > target.width || size.height > target.height) {
    double dx = target.width / size.width;
    double dy = target.height / size.height;
    if (dx < dy) {
      size = _Size.from(size.width * dx, size.height * dx);
    } else {
      size = _Size.from(size.width * dy, size.height * dy);
    }
  }
  return size;
}

class _Size {
  _Size(this.width, this.height);

  final int width;
  final int height;

  @override
  String toString() => '($width, $height)';

  static _Size from(double width, double height) =>
      _Size(width.toInt(), height.toInt());

}
