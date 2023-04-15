/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../client/filesys/paths.dart';

class LocalStorage {
  factory LocalStorage() => _instance;
  static final LocalStorage _instance = LocalStorage._internal();
  LocalStorage._internal();

  //
  //  Directories
  //

  ///  Protected caches directory
  ///  (meta/visa/document, image/audio/video, ...)
  ///
  /// @return '/storage/emulated/0/Android/data/chat.dim.sechat/files'
  Future<String> get cachesDirectory async {
    if (Platform.isAndroid) {
      // Android
      Directory? dir = await getExternalStorageDirectory();
      assert(dir != null, 'failed to get external storage directory');
      return dir!.path;
    } else {
      // iOS, macOS, Linux, Windows
      Directory? dir = await getDownloadsDirectory();
      assert(dir != null, 'failed to get downloads directory');
      return dir!.path;
    }
    // // "/sdcard/chat.dim.sechat/caches"
    // return await ChannelManager().storageChannel.cachesDirectory;
  }

  ///  Protected temporary directory
  ///  (uploading, downloaded)
  ///
  /// @return '/data/user/0/chat.dim.sechat/cache'
  Future<String> get temporaryDirectory async {
    // Android, iOS, macOS, Linux, Windows
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
    return Paths.append(dir, 'avatar', aa, bb, filename);
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
    return Paths.append(dir, 'files', aa, bb, filename);
  }

  ///  Encrypted data file path
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{tmp}/upload/{filename}"
  Future<String> getUploadFilePath(String filename) async {
    String dir = await temporaryDirectory;
    return Paths.append(dir, 'upload', filename);
  }

  ///  Encrypted data file path
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{tmp}/download/{filename}"
  Future<String> getDownloadFilePath(String filename) async {
    String dir = await temporaryDirectory;
    return Paths.append(dir, 'download', filename);
  }

}
