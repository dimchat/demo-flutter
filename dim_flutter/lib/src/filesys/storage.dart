/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:pnf/dos.dart';

import '../common/constants.dart';
import '../sqlite/helper/connector.dart';
import 'local.dart';


class CacheFileManager {
  factory CacheFileManager() => _instance;
  static final CacheFileManager _instance = CacheFileManager._internal();
  CacheFileManager._internal() {
    _init();
  }

  _FileScanner? _db1Scanner;
  _FileScanner? _db2Scanner;
  _FileScanner? _db3Scanner;

  _FileScanner? _avatarScanner;
  _FileScanner? _cachesScanner;
  _FileScanner? _uploadScanner;
  _FileScanner? _downloadScanner;

  _FileCleaner? _avatarCleaner;
  _FileCleaner? _cachesCleaner;
  _FileCleaner? _uploadCleaner;
  _FileCleaner? _downloadCleaner;

  void _init() async {
    LocalStorage local = LocalStorage();
    String caches = await local.cachesDirectory;
    String tmp = await local.temporaryDirectory;
    String dbDir1 = await DBPath.getDatabaseDirectory(null);
    String dbDir2 = await DBPath.getDatabaseDirectory('.dkd');
    String dbDir3 = await DBPath.getDatabaseDirectory('.dim');
    // create scanners & cleaners
    _db1Scanner = _FileScanner(dbDir1);
    _db2Scanner = _FileScanner(dbDir2);
    _db3Scanner = _FileScanner(dbDir3);
    _avatarCleaner = _FileCleaner(_avatarScanner = _FileScanner(Paths.append(caches, 'avatar')));
    _cachesCleaner = _FileCleaner(_cachesScanner = _FileScanner(Paths.append(caches, 'files')));
    _uploadCleaner = _FileCleaner(_uploadScanner = _FileScanner(Paths.append(tmp, 'upload')));
    _downloadCleaner = _FileCleaner(_downloadScanner = _FileScanner(Paths.append(tmp, 'download')));
  }

  bool get refreshing => _db1Scanner?._refreshing == true
      || _db2Scanner?._refreshing == true
      || _db3Scanner?._refreshing == true
      || _avatarScanner?._refreshing == true
      || _cachesScanner?._refreshing == true
      || _uploadScanner?._refreshing == true
      || _downloadScanner?._refreshing == true;

  String get dbSummary {
    int count = 0;
    count += _db1Scanner?._count ?? 0;
    count += _db2Scanner?._count ?? 0;
    count += _db3Scanner?._count ?? 0;
    int size = 0;
    size += _db1Scanner?._size ?? 0;
    size += _db2Scanner?._size ?? 0;
    size += _db3Scanner?._size ?? 0;
    return _summary(count: count, size: size);
  }
  String get avatarSummary => _avatarScanner?.summary ?? '';
  String get cacheSummary => _cachesScanner?.summary ?? '';
  String get uploadSummary => _uploadScanner?.summary ?? '';
  String get downloadSummary => _downloadScanner?.summary ?? '';

  String get summary {
    int size = 0;
    size += _db1Scanner?._size ?? 0;
    size += _db2Scanner?._size ?? 0;
    size += _db3Scanner?._size ?? 0;
    size += _avatarScanner?._size ?? 0;
    size += _cachesScanner?._size ?? 0;
    size += _uploadScanner?._size ?? 0;
    size += _downloadScanner?._size ?? 0;
    return _readableSize(size);
  }

  void scanAll() {
    _db1Scanner?.scan();
    _db2Scanner?.scan();
    _db3Scanner?.scan();
    _avatarScanner?.scan();
    _cachesScanner?.scan();
    _uploadScanner?.scan();
    _downloadScanner?.scan();
  }

  void cleanAvatars() => _avatarCleaner?.clean();
  void cleanCaches() => _cachesCleaner?.clean();
  void cleanUploads() => _uploadCleaner?.clean();
  void cleanDownloads() => _downloadCleaner?.clean();

}


class _FileCleaner with Logging {
  _FileCleaner(this._scanner);

  final _FileScanner _scanner;

  bool _cleaning = false;

  void clean() async {
    if (_cleaning) {
      return;
    }
    _cleaning = true;
    await run();
    _cleaning = false;
    _scanner.scan();
  }

  // protected
  Future<void> run() async {
    String root = _scanner._root;
    try {
      await _cleanDir(Directory(root));
    } catch (e, st) {
      logError('failed to clean directory: $root, $e, $st');
    }
  }

  Future<void> _cleanDir(Directory dir) async {
    logInfo('cleaning directory: $dir');
    Stream<FileSystemEntity> files = dir.list();
    await files.forEach((item) async {
      // directories, files, and links
      // does not include the special entries `'.'` and `'..'`.
      if (item is Directory) {
        await _cleanDir(item);
      } else if (item is File) {
        try {
          logWarning('deleting cache file: $item');
          // await item.delete();
          await Paths.delete(item.path);
        } catch (e, st) {
          logError('failed to check file: $item, $e, $st');
        }
      } else {
        assert(false, 'ignore link: $item');
      }
    });
  }

}


class _FileScanner with Logging {
  _FileScanner(this._root);

  final String _root;

  int _count = 0;
  int _size = 0;

  bool _refreshing = false;

  String get summary => _summary(count: _count, size: _size);

  void scan() async {
    if (_refreshing) {
      return;
    } else {
      _count = 0;
      _size = 0;
    }
    _refreshing = true;
    await run();
    _refreshing = false;
    // post notification: 'CacheScanFinished'
    var nc = NotificationCenter();
    await nc.postNotification(NotificationNames.kCacheScanFinished, this, {
      'root': _root,
    });
  }

  // protected
  Future<void> run() async {
    try {
      await _scanDir(Directory(_root));
    } catch (e, st) {
      logError('failed to scan directory: $_root, $e, $st');
    }
  }

  Future<void> _scanDir(Directory dir) async {
    logInfo('scanning directory: $dir');
    Stream<FileSystemEntity> files = dir.list();
    await files.forEach((item) async {
      // directories, files, and links
      // does not include the special entries `'.'` and `'..'`.
      if (item is Directory) {
        await _scanDir(item);
      } else if (item is File) {
        try {
          await _checkFile(item);
        } catch (e, st) {
          logError('failed to check file: $item, $e, $st');
        }
      } else {
        assert(false, 'ignore link: $item');
      }
    });
  }

  Future<bool> _checkFile(File file) async {
    int length = await file.length();
    if (length < 0) {
      logError('file error: $file, $length');
      return false;
    }
    _count += 1;
    _size += length;
    // post notification: 'CacheFileFound'
    var nc = NotificationCenter();
    await nc.postNotification(NotificationNames.kCacheFileFound, this, {
      'root': _root,
      'path': file.path,
      'length': length,
    });
    return true;
  }

}

String _summary({required int count, required int size}) {
  String text = _readableSize(size);
  if (count < 2) {
    return 'Contains $count file, totaling $text';
  }
  return 'Contains $count files, totaling $text';
}

String _readableSize(int size) {
  if (size < 2) {
    return '$size byte';
  } else if (size < kiloBytes) {
    return '$size bytes';
  }
  int cnt;
  String uni;
  if (size < megaBytes) {
    cnt = kiloBytes;
    uni = 'KB';
  } else if (size < gigaBytes) {
    cnt = megaBytes;
    uni = 'MB';
  } else if (size < teraBytes) {
    cnt = gigaBytes;
    uni = 'GB';
  } else {
    cnt = teraBytes;
    uni = 'TB';
  }
  double num = size.toDouble() / cnt;
  return '${num.toStringAsFixed(1)} $uni';
}
const int kiloBytes = 1024;
const int megaBytes = 1024 * kiloBytes;
const int gigaBytes = 1024 * megaBytes;
const int teraBytes = 1024 * gigaBytes;
