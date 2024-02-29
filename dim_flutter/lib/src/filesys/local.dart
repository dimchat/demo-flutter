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

import 'package:lnc/log.dart';
import 'package:path_provider/path_provider.dart';

import '../channels/manager.dart';
import '../common/platform.dart';
import 'external.dart';
import 'paths.dart';

class LocalStorage {
  factory LocalStorage() => _instance;
  static final LocalStorage _instance = LocalStorage._internal();
  LocalStorage._internal();

  DateTime? _lastBurn;

  ///  Avatar image file path
  ///
  /// @param filename - image filename: hex(md5(data)) + ext
  /// @return "{caches}/avatar/{AA}/{BB}/{filename}"
  Future<String?> getAvatarFilePath(String filename) async {
    String? dir = await cachesDirectory;
    if (dir == null) {
      Log.error('failed to get caches directory for avatar: $filename');
      return null;
    } else if (filename.length < 4) {
      assert(false, 'invalid filename: $filename');
      return Paths.append(dir, filename);
    }
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    return Paths.append(dir, 'avatar', aa, bb, filename);
  }

  ///  Cached file path
  ///  (image, audio, video, ...)
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{caches}/files/{AA}/{BB}/{filename}"
  Future<String?> getCacheFilePath(String filename) async {
    String? dir = await cachesDirectory;
    if (dir == null) {
      Log.error('failed to get caches directory for file: $filename');
      return null;
    } else if (filename.length < 4) {
      assert(false, 'invalid filename: $filename');
      return Paths.append(dir, filename);
    }
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    return Paths.append(dir, 'files', aa, bb, filename);
  }

  ///  Encrypted data file path
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{tmp}/upload/{filename}"
  Future<String?> getUploadFilePath(String filename) async {
    String? dir = await temporaryDirectory;
    if (dir == null) {
      Log.error('failed to get caches directory to upload: $filename');
      return null;
    }
    return Paths.append(dir, 'upload', filename);
  }

  ///  Encrypted data file path
  ///
  /// @param filename - messaged filename: hex(md5(data)) + ext
  /// @return "{tmp}/download/{filename}"
  Future<String?> getDownloadFilePath(String filename) async {
    String? dir = await temporaryDirectory;
    if (dir == null) {
      Log.error('failed to get caches directory to download: $filename');
      return null;
    }
    return Paths.append(dir, 'download', filename);
  }

  //
  //  Directories
  //

  ///  Protected caches directory
  ///  (meta/visa/document, image/audio/video, ...)
  ///
  /// Android: "/sdcard/Android/data/chat.dim.sechat/cache"
  ///     iOS: "/Application/{...}/Library/Caches"
  Future<String?> get cachesDirectory async {
    if (DevicePlatform.isWeb) {
      return '/cache';
    }
    if (DevicePlatform.isIOS || DevicePlatform.isAndroid) {
      ChannelManager man = ChannelManager();
      return await man.ftpChannel.cachesDirectory;
    }
    Directory dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  ///  Protected temporary directory
  ///  (uploading, downloaded)
  ///
  /// Android: "/data/data/chat.dim.sechat/cache"
  ///     iOS: "/Application/{...}/tmp"
  Future<String?> get temporaryDirectory async {
    if (DevicePlatform.isWeb) {
      return '/tmp';
    }
    if (DevicePlatform.isIOS || DevicePlatform.isAndroid) {
      ChannelManager man = ChannelManager();
      return await man.ftpChannel.temporaryDirectory;
    }
    Directory dir = await getTemporaryDirectory();
    return dir.path;
  }

  Future<int> burnAll(DateTime expired) async {
    DateTime now = DateTime.now();
    // check last time
    DateTime? last = _lastBurn;
    if (last != null) {
      int elapsed = now.millisecondsSinceEpoch - last.millisecondsSinceEpoch;
      if (elapsed < 15000) {
        // too frequently
        return 0;
      }
    }
    _lastBurn = now;
    // cleanup cached files
    String? path = await cachesDirectory;
    if (path == null) {
      Log.error('failed to get caches directory for burning');
      return 0;
    }
    path = Paths.append(path, 'files');
    Directory dir = Directory(path);
    return await ExternalStorage.cleanupDirectory(dir, expired);
  }

}
