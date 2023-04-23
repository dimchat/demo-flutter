import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'alert.dart';

typedef OnImagePicked = void Function(String path);
typedef OnImageRead = void Function(String path, Uint8List data);

void openImagePicker(BuildContext context,
    {OnImagePicked? onPicked, required OnImageRead onRead}) {
  showCupertinoModalPopup(context: context, builder: (context) {
    return CupertinoActionSheet(
      // title: const Text('Photo'),
      // message: const Text('Take a photo from your camera or album'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => _openImagePicker(context, true, onPicked, onRead),
          child: const Text('Camera'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => _openImagePicker(context, false, onPicked, onRead),
          child: const Text('Album'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ],
    );
  });
}

void _openImagePicker(BuildContext context, bool camera, OnImagePicked? onPicked, OnImageRead onRead) {
  Navigator.pop(context);
  ImagePicker picker = ImagePicker();
  ImageSource source = camera ? ImageSource.camera : ImageSource.gallery;
  picker.pickImage(source: source).then((file) {
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
}

Future<Uint8List> compressThumbnail(Uint8List jpeg) async {
  return await FlutterImageCompress.compressWithList(jpeg,
    minHeight: 128,
    minWidth: 128,
    quality: 20,
  );
}
