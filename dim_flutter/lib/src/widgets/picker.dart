import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lnc/lnc.dart';

import '../filesys/paths.dart';
import 'alert.dart';
import 'permissions.dart';

typedef OnImagePicked = void Function(String path);
typedef OnImageRead = void Function(String path, Uint8List data);

void openImagePicker(BuildContext context, {OnImagePicked? onPicked, required OnImageRead onRead}) =>
    Alert.actionSheet(context, null, null,
      'Camera'.tr, () => requestCameraPermissions(context,
        onGranted: (context) => _openImagePicker(context, true, onPicked, onRead),
      ),
      'Album'.tr, () => requestPhotosPermissions(context,
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
void adjustImage(Uint8List jpeg, int size, void Function(Uint8List small) onSank) {
  int fileSize = jpeg.length;
  int maxFileSize = size * size;
  if (fileSize <= maxFileSize) {
    Log.info('no need to resize: $fileSize <= $maxFileSize');
    onSank(jpeg);
  } else {
    double ratio = sqrt(maxFileSize / fileSize);
    Log.info('resize image with ratio: $ratio, $fileSize > $maxFileSize');
    _resolveImage(jpeg, (ui.Image image) async {
      double width = image.width * ratio;
      double height = image.height * ratio;
      // zoom out
      Uint8List small = await FlutterImageCompress.compressWithList(jpeg,
        minWidth: width.toInt(),
        minHeight: height.toInt(),
      );
      Log.info('resized: ${image.width} * ${image.height} => $width * $height,'
          ' $fileSize => ${small.length} bytes');
      onSank(jpeg);
    });
  }
}

/// fetch size info from image data
void _resolveImage(Uint8List jpeg, void Function(ui.Image image) onResolved) =>
    MemoryImage(jpeg).resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) => onResolved(info.image))
    );
