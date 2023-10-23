import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import 'pnf.dart';


///
///   PNG - Portable Network Graphics
///


class PNGLoader extends PNFLoader {
  PNGLoader(super.pnf);

  Future<ImageProvider<Object>?> loadImage(String rootDirectory, {ProgressCallback? onReceiveProgress}) async {
    ImageProviderFactory factory = ImageProviderFactory();
    ImageProvider? image;
    String? path;
    // 1. check URL
    Uri? url = pnf.url;
    if (url != null) {
      image = factory.getImage(url.toString());
      if (image != null) {
        Log.info('got cached image: $url');
        return image;
      }
    }
    // 2. check filename
    String? filename = pnf.filename;
    if (filename != null) {
      path = getCacheFilePath(filename, rootDirectory);
      image = factory.getImage(path);
      if (image != null) {
        Log.info('got cached image: $filename');
        return image;
      }
    }
    // 3. check cached for URL
    String? name = cacheName;
    if (name != null && name != filename) {
      path = getCacheFilePath(name, rootDirectory);
      image = factory.getImage(path);
      if (image != null) {
        Log.info('got cached image: $name');
        return image;
      }
    }
    // 4. download file data
    Uint8List? data = await download(rootDirectory, onReceiveProgress: onReceiveProgress);
    if (data == null) {
      Log.error('PNF data not found: $pnf');
      return null;
    }
    // 5. create image and cache in memory
    image = MemoryImage(data);
    if (url != null) {
      factory.cacheImage(url.toString(), image);
    }
    if (filename != null) {
      factory.cacheImage(filename, image);
    }
    if (name != null && name != filename) {
      factory.cacheImage(name, image);
    }
    // OK
    return image;
  }

}


class ImageProviderFactory {
  factory ImageProviderFactory() => _instance;
  static final ImageProviderFactory _instance = ImageProviderFactory._internal();
  ImageProviderFactory._internal();

  // filename => imageProvider
  //     path => imageProvider
  //      url => imageProvider
  final Map<String, ImageProvider> _providers = WeakValueMap();

  /// Get image with filename (or URL/path string)
  ImageProvider<Object>? getImage(String name) => _providers[name];

  /// Cache image with filename (or URL/path string)
  void cacheImage(String name, ImageProvider image) => _providers[name] = image;

  /// Load image from file
  Future<ImageProvider<Object>?> loadImage(String path) async {
    // check memory cache
    ImageProvider? image = _providers[path];
    if (image == null) {
      // load from file
      Uint8List? data = await _IPHelper.loadImageData(path);
      if (data != null) {
        image = MemoryImage(data);
        _providers[path] = image;
      }
    }
    return image;
  }

}

class _IPHelper {

  static Future<Uint8List?> loadImageData(String path) async {
    // return FileImage(File(path));
    try {
      File file = File(path);
      if (!await file.exists()) {
        assert(false, 'image file not exists: $path');
        return null;
      }
      int end = await file.length();
      Uint8List bytes = file.readAsBytesSync();
      if (end != bytes.length || end <= 32) {
        Log.error('[IMG] file size error: $end(${bytes.length}');
        file.delete();
        return null;
      }
      end = 32;  // only check the head
      int pos = 0;
      for (; pos < end; ++pos) {
        if (bytes[pos] != 0) {
          break;
        }
      }
      if (pos == end) {
        // data error
        Log.warning('[IMG] image file error, remove it: $path');
        file.delete();
        return null;
      }
      return bytes;
    } catch (e) {
      Log.error('[IMG] failed to get image from file: $path, error: $e');
      return null;
    }
  }

}
