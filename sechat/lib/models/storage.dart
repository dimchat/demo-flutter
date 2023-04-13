import 'dart:io';

import 'package:path/path.dart' as utils;
import 'package:path_provider/path_provider.dart';

class Paths {

  static String join(String a, [String? b, String? c, String? d, String? e]) {
    return utils.join(a, b, c, d, e);
  }

  static Future<bool> mkdirs(String path) async {
    Directory dir = Directory(path);
    await dir.create(recursive: true);
    return dir.exists();
  }

}

class LocalStorage {

  //
  //  Directories
  //

  ///  Protected caches directory
  ///  (meta/visa/document, image/audio/video, ...)
  ///
  /// @return '/storage/emulated/0/Android/data/chat.dim.sechat/files'
  Future<String> get cachesDirectory async {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } on UnsupportedError {
      // Android?
      dir = await getExternalStorageDirectory();
    }
    return dir!.path;
    // // "/sdcard/chat.dim.sechat/caches"
    // return await ChannelManager().storageChannel.cachesDirectory;
  }

  ///  Protected temporary directory
  ///  (uploading, downloaded)
  ///
  /// @return '/data/user/0/chat.dim.sechat/cache'
  Future<String> get temporaryDirectory async {
    return (await getTemporaryDirectory()).path;
    // // ['/storage/emulated/0/Android/data/chat.dim.sechat/cache',
    // //  '/storage/1700-1B1B/Android/data/chat.dim.sechat/cache']
    // List<Directory>? dirs = await getExternalCacheDirectories();
    // return dirs![0].path;
    // // "/sdcard/chat.dim.sechat/tmp"
    // return await ChannelManager().storageChannel.temporaryDirectory;
  }

  //
  //  Paths
  //

  ///  Avatar image file path
  ///
  /// @param filename - image filename: hex(md5(data)) + ext
  /// @return "{caches}/avatar/{AA}/{BB}/{filename}"
  Future<String> getAvatarFilePath(String filename) async {
    String dir = await cachesDirectory;
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    return Paths.join(dir, 'avatar', aa, bb, filename);
  }

  ///  Cached file path
  ///  (image, audio, video, ...)
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{caches}/files/{AA}/{BB}/{filename}"
  Future<String> getCacheFilePath(String filename) async {
    String dir = await cachesDirectory;
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    return Paths.join(dir, 'files', aa, bb, filename);
  }

  ///  Encrypted data file path
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{tmp}/upload/{filename}"
  Future<String> getUploadFilePath(String filename) async {
    String dir = await temporaryDirectory;
    return Paths.join(dir, 'upload', filename);
  }

  ///  Encrypted data file path
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{tmp}/download/{filename}"
  Future<String> getDownloadFilePath(String filename) async {
    String dir = await temporaryDirectory;
    return Paths.join(dir, 'download', filename);
  }

}
