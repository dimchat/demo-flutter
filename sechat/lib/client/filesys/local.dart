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

import 'package:lnc/lnc.dart';
import 'package:path_provider/path_provider.dart';

import 'paths.dart';

class LocalStorage {
  factory LocalStorage() => _instance;
  static final LocalStorage _instance = LocalStorage._internal();
  LocalStorage._internal();

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

  //
  //  Directories
  //

  ///  Protected caches directory
  ///  (meta/visa/document, image/audio/video, ...)
  ///
  /// Android: "/sdcard/Android/data/chat.dim.sechat/cache"
  ///     iOS: "/Application/{...}/Library/Caches"
  Future<String> get cachesDirectory async {
    _SysDir dos = _SysDir();
    if (Platform.isAndroid) {
      // Android
      List<String> dirs = await dos.externalCacheDirectories;
      if (dirs.isNotEmpty) {
        // "/sdcard/Android/data/chat.dim.sechat/cache"
        return dirs.first;
      }
      String dir = await dos.externalStorageDirectory;
      if (dir.isEmpty) {
        Log.error('failed to get external storage directory');
      } else {
        // "/sdcard/Android/data/chat.dim.sechat/files"
        return dir;
      }
    } else {
      // iOS, macOS, Linux, Windows
      String dir = await dos.libraryDirectory;
      if (dir.isNotEmpty) {
        // NSCachesDirectory
        // "/Application/{...}/Library/Caches"
        return Paths.append(dir, 'Caches');
      }
      dir = await dos.downloadsDirectory;
      if (dir.isEmpty) {
        Log.error('failed to get download directory');
      } else {
        // "/Application/{...}/Downloads"
        return dir;
      }
    }
    // Android: "/data/data/chat.dim.sechat/cache"
    //     iOS: "/Application/{...}/Library/Caches"
    return await dos.temporaryDirectory;
  }

  ///  Protected temporary directory
  ///  (uploading, downloaded)
  ///
  /// Android: "/data/data/chat.dim.sechat/cache"
  ///     iOS: "/Application/{...}/Library/Caches"
  Future<String> get temporaryDirectory async {
    _SysDir dos = _SysDir();
    // Android: "/data/data/chat.dim.sechat/cache"
    //     iOS: "/Application/{...}/Library/Caches"
    return await dos.temporaryDirectory;
  }

}

//  ------------------------------------------------------------------------
//    Directory                      Android   iOS   Linux  macOS  Windows
//  ------------------------------------------------------------------------
//    Temporary                        ✔️       ✔️     ✔️      ✔️      ✔️
//    Application Support              ✔️       ✔️     ✔️      ✔️      ✔️
//    Application Library              ❌       ✔️     ❌️      ✔️      ❌
//    Application Documents            ✔️       ✔️     ✔️      ✔️      ✔️
//    External Storage                 ✔️       ❌     ❌      ❌      ❌
//    External Cache Directories       ✔️       ❌     ❌      ❌      ❌
//    External Storage Directories     ✔️       ❌     ❌      ❌      ❌
//    Downloads                        ❌       ✔️     ✔️      ✔️      ✔️
//  ------------------------------------------------------------------------

class _SysDir {
  factory _SysDir() => _instance;
  static final _SysDir _instance = _SysDir._internal();
  _SysDir._internal();

  /// iOS & macOS: NSCachesDirectory
  ///              "/Application/{...}/Library/Caches"
  ///     Android: Context.getCacheDir()
  ///              "/data/data/chat.dim.sechat/cache"
  Future<String> get temporaryDirectory async {
    String? dir = _temporaryDir;
    if (dir == null) {
      // FIXME: NSTemporaryDirectory() on iOS?
      _temporaryDir = dir = (await getTemporaryDirectory()).path;
    }
    return dir;
  }
  String? _temporaryDir;

  /// iOS & macOS: NSApplicationSupportDirectory
  ///              "/Application/{...}/Library/Application Support"
  ///     Android: PathUtils.getFilesDir()
  ///              "/data/data/chat.dim.sechat/files"
  Future<String> get applicationSupportDirectory async {
    String? dir = _appSupportDir;
    if (dir == null) {
      _appSupportDir = dir = (await getApplicationSupportDirectory()).path;
    }
    return dir;
  }
  String? _appSupportDir;

  /// iOS & macOS: NSLibraryDirectory
  ///              "/Application/{...}/Library"
  ///     Android: null
  Future<String> get libraryDirectory async {
    String? dir = _libraryDir;
    if (dir == null) {
      if (Platform.isIOS || Platform.isMacOS) {
        dir = (await getLibraryDirectory()).path;
      } else {
        dir = '';
      }
      _libraryDir = dir;
    }
    return dir;
  }
  String? _libraryDir;

  /// iOS & macOS: NSDocumentDirectory
  ///              "/Application/{...}/Documents"
  ///     Android: PathUtils.getDataDirectory()
  ///              "/data/data/chat.dim.sechat/app_flutter"
  Future<String> get applicationDocumentsDirectory async {
    String? dir = _appDocumentsDir;
    if (dir == null) {
      _appDocumentsDir = dir = (await getApplicationDocumentsDirectory()).path;
    }
    return dir;
  }
  String? _appDocumentsDir;

  /// iOS & macOS: null
  ///     Android: getExternalFilesDir(null)
  ///              "/sdcard/Android/data/chat.dim.sechat/files"
  Future<String> get externalStorageDirectory async {
    String? dir = _externalStorageDir;
    if (dir == null) {
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory())?.path ?? '';
      } else {
        dir = '';
      }
      _externalStorageDir = dir;
    }
    return dir;
  }
  String? _externalStorageDir;

  /// iOS & macOS: null
  ///     Android: Context.getExternalCacheDirs()
  ///              ["/sdcard/Android/data/chat.dim.sechat/cache", ...]
  Future<List<String>> get externalCacheDirectories async {
    List<String>? dirs = _externalCacheDirs;
    if (dirs == null) {
      if (Platform.isAndroid) {
        dirs = _paths(await getExternalCacheDirectories());
      } else {
        dirs = [];
      }
      _externalCacheDirs = dirs;
    }
    return dirs;
  }
  List<String>? _externalCacheDirs;

  /// iOS & macOS: null
  ///     Android: Context.getExternalFilesDirs(type)
  ///              ["/sdcard/Android/data/chat.dim.sechat/files", ...]
  Future<List<String>> get externalStorageDirectories async {
    List<String>? dirs = _externalStorageDirs;
    if (dirs == null) {
      if (Platform.isAndroid) {
        dirs = _paths(await getExternalStorageDirectories());
      } else {
        dirs = [];
      }
      _externalStorageDirs = dirs;
    }
    return dirs;
  }
  List<String>? _externalStorageDirs;

  /// iOS & macOS: NSDownloadsDirectory
  ///              "/Application/{...}/Downloads"
  ///     Android: null
  Future<String> get downloadsDirectory async {
    String? dir = _downloadsDir;
    if (dir == null) {
      if (Platform.isIOS || Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        dir = (await getDownloadsDirectory())?.path ?? '';
      } else {
        dir = '';
      }
      _downloadsDir = dir;
    }
    return dir;
  }
  String? _downloadsDir;

  static List<String> _paths(List<Directory>? future) =>
      future?.map((e) => e.path).toList() ?? [];

}
