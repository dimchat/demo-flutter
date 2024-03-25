/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:dim_client/dim_common.dart';
import 'package:lnc/log.dart';

import '../ui/icons.dart';


abstract class ImageUtils {

  static Image? getImage(String small, {double? width, double? height, BoxFit? fit}) {
    assert(small.isNotEmpty, 'image info empty');
    if (small.contains('://')) {
      return networkImage(small, width: width, height: height, fit: fit);
    } else {
      var ted = TransportableData.parse(small);
      Uint8List? bytes = ted?.data;
      if (bytes != null && bytes.isNotEmpty) {
        return memoryImage(bytes, width: width, height: height, fit: fit);
      }
    }
    assert(false, 'thumbnail error: $small');
    return null;
  }

  static ImageProvider? getProvider(String small) {
    assert(small.isNotEmpty, 'image info empty');
    if (small.contains('://')) {
      return networkImageProvider(small);
    } else {
      var ted = TransportableData.parse(small);
      Uint8List? bytes = ted?.data;
      if (bytes != null && bytes.isNotEmpty) {
        return memoryImageProvider(bytes);
      }
    }
    assert(false, 'thumbnail error: $small');
    return null;
  }

  //
  //  Image
  //

  static Image image(ImageProvider img, {
    double? width, double? height, BoxFit? fit,
  }) => Image(image: img, width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  static Image networkImage(String src, {
    double? width, double? height, BoxFit? fit,
  }) => Image.network(src, width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  static Image memoryImage(Uint8List bytes, {
    double? width, double? height, BoxFit? fit,
  }) => Image.memory(bytes, width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  static Image fileImage(String path, {
    double? width, double? height, BoxFit? fit,
  }) => Image.file(File(path), width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  //
  //  Provider
  //

  static ImageProvider networkImageProvider(String src) =>
      NetworkImage(src);

  static ImageProvider memoryImageProvider(Uint8List bytes) =>
      MemoryImage(bytes);

  static ImageProvider fileImageProvider(String path) =>
      FileImage(File(path));

  //
  //  Compression
  //

  /// compress image for thumbnail (128*128) low quality
  static Future<Uint8List?> compressThumbnail(Uint8List jpeg) async =>
      await compress(jpeg, minHeight: 128, minWidth: 128, quality: 20,);

  static Future<Uint8List?> compress(Uint8List image,
      {required int minWidth, required int minHeight, int quality = 95}) async {
    try {
      return await FlutterImageCompress.compressWithList(image,
        minWidth: minWidth, minHeight: minHeight, quality: quality,);
    } catch (e, st) {
      Log.error('[JPEG] failed to compress image: $minWidth x $minHeight, q: $quality, $e, $st');
      return null;
    }
  }

}

Widget _noImage({double? width, double? height}) {
  Log.error('no image: $width, $height');
  if (width == null && height == null) {
    return const Icon(AppIcons.noImageIcon, color: CupertinoColors.systemRed,);
  }
  return Stack(
    alignment: AlignmentDirectional.center,
    children: [
      SizedBox(width: width, height: height,),
      const Icon(AppIcons.noImageIcon, color: CupertinoColors.systemRed,),
    ],
  );
}
