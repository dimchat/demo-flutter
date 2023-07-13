import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lnc/lnc.dart';

import '../filesys/paths.dart';
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
        return;
      }
      String path = file.path;
      String? filename = Paths.filename(path);
      Alert.confirm(context, 'Pick Image', '$filename',
        okAction: () {
          if (onPicked != null) {
            onPicked(path);
          }
          file.readAsBytes().then((data) {
            Log.debug('image file length: ${data.length}, path: $path');
            onRead(path, data);
          }).onError((error, stackTrace) {
            Alert.show(context, 'Image File Error', '$error');
          });
        }
      );
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


///  Check whether needs resize down a large image
///
/// @param jpeg   - image data
/// @param onSank - callback with small image data after resized down
/// @param size   - target size (width & height)
void adjustImage(Uint8List jpeg, int size, void Function(Uint8List small) onSank) =>
    _resolveImage(jpeg, (ui.Image image) async {
      _Size imageSize = _Size(image.width, image.height);
      _Size targetSize = _Size(size, size);
      // check image size
      if (_needsResize(imageSize: imageSize, targetSize: targetSize, dataLength: jpeg.length)) {
        // zoom out
        _Size size = _resizeDown(imageSize: imageSize, targetSize: targetSize);
        Uint8List small = await FlutterImageCompress.compressWithList(jpeg,
          minWidth: size.width,
          minHeight: size.height,
        );
        Log.info('resized: $imageSize => $size; ${jpeg.length} => ${small.length} bytes');
        jpeg = small;
      } else {
        Log.info('no need to resize: $imageSize => $targetSize');
      }
      onSank(jpeg);
    });

/// fetch size info from image data
void _resolveImage(Uint8List jpeg, void Function(ui.Image image) onResolved) =>
    MemoryImage(jpeg).resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) => onResolved(info.image))
    );

/// check whether image is too big to be resized
bool _needsResize({required _Size imageSize, required _Size targetSize, required int dataLength}) {
  assert(targetSize.width > 0 && targetSize.height > 0, 'max size error: $targetSize');
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    assert(false, 'size error: $imageSize');
    return false;
  }
  final int sx = targetSize.width;   // small:  1024, 2048, ...
  final int sy = targetSize.height;  //         1024, 2048, ...
  final int mx = sx + (sx >> 1);     // medium: 1536, 3072, ...
  final int my = sy + (sy >> 1);     //         1536, 3072, ...
  final int lx = sx << 1;            // large:  2048, 4096, ...
  final int ly = sy << 1;            //         2048, 4096, ...
  final int medium = sx * sy;        // m-len:  1 MB, 4 MB, ...
  final int large = medium << 1;     // l-len:  2 MB, 8 MB, ...
  if (imageSize.width <= sx && imageSize.height <= sy) {
    // smaller than target size
    return false;
  } else if (imageSize.width > lx || imageSize.height > ly) {
    // too big than target size
    return true;
  } else if (imageSize.width > mx) {
    // width is large enough, check height & data length
    return imageSize.height > sy || dataLength > medium;
  } else if (imageSize.height > my) {
    // height is large enough, check width & data length
    return imageSize.width > sx || dataLength > medium;
  }
  // image data is too large?
  return dataLength > large;
}

/// resize (width, height) to no larger than (maxWidth, maxHeight)
_Size _resizeDown({required _Size imageSize, required _Size targetSize}) {
  if (imageSize.width > targetSize.width || imageSize.height > targetSize.height) {
    double dx = targetSize.width / imageSize.width;
    double dy = targetSize.height / imageSize.height;
    if (dx < dy) {
      imageSize = _Size.from(imageSize.width * dx, imageSize.height * dx);
    } else {
      imageSize = _Size.from(imageSize.width * dy, imageSize.height * dy);
    }
  }
  return imageSize;
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
