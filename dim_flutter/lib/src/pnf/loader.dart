/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
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
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mutex/mutex.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../client/shared.dart';
import '../common/constants.dart';
import '../filesys/external.dart';
import '../filesys/paths.dart';

enum PortableNetworkStatus {
  init,
  downloading,
  decrypting,
  success,
  error,
}

abstract class PortableNetworkLoader {
  PortableNetworkLoader(this.pnf);

  final PortableNetworkFile pnf;

  /// file content received
  Uint8List? _bytes;
  Uint8List? get content => _bytes;

  /// count of bytes received
  int _count = 0;
  int get count => _count;
  /// total bytes receiving
  int _total = 0;
  int get total => _total;

  /// loader status
  PortableNetworkStatus _status = PortableNetworkStatus.init;
  PortableNetworkStatus get status => _status;
  setStatus(PortableNetworkStatus current) {
    PortableNetworkStatus previous = _status;
    _status = current;
    if (previous != current) {
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kPortableNetworkStatusChanged, this, {
        'URL': pnf.url,
        'previous': previous,
        'current': current,
      });
    }
  }

  /// Temporary Directory
  ///     Android -
  ///     iOS -
  Future<String?> get temporaryDirectory;
  /// Caches Directory
  ///     Android -
  ///     iOS -
  Future<String?> get cachesDirectory;

  /// "{tmp}/filename"
  Future<String?> get temporaryFilePath async {
    String? dir = await temporaryDirectory;
    if (dir == null) {
      return null;
    }
    return Paths.append(dir, filename);
  }
  /// "{caches}/{AA}/{BB}/filename"
  Future<String?> get cacheFilePath async {
    String? dir = await cachesDirectory;
    if (dir == null) {
      return null;
    }
    String? name = filename;
    if (name == null || name.isEmpty) {
      assert(false, 'PNF error: $pnf');
      return null;
    } else if (name.length < 4) {
      assert(false, 'invalid filename: $name, $pnf');
      return Paths.append(dir, name);
    }
    String aa = name.substring(0, 2);
    String bb = name.substring(2, 4);
    return Paths.append(dir, aa, bb, name);
  }

  String? get filename {
    String? name = pnf.filename;
    Uri? url = pnf.url;
    return url == null ? name : _FilenameUtils.filenameFromURL(url, name);
  }

  Future<Uint8List?> _decrypt(Uint8List data, String cachePath) async {
    var nc = NotificationCenter();
    // 1. check password
    DecryptKey? password = pnf.password;
    if (password == null) {
      // password not found, means it's not an encrypted data
      _bytes = data;
    } else {
      setStatus(PortableNetworkStatus.decrypting);
      // try to decrypt with password
      Uint8List? plaintext = password.decrypt(data, pnf);
      if (plaintext == null || plaintext.isEmpty) {
        assert(false, 'failed to decrypt data (${data.length} bytes) with password: $password');
        nc.postNotification(NotificationNames.kPortableNetworkError, this, {
          'URL': pnf.url,
          'error': 'Failed to decrypt data',
        });
        setStatus(PortableNetworkStatus.error);
        return null;
      }
      data = plaintext;
      _bytes = plaintext;
    }
    // 2. save original file content
    Log.info('[PNF] save cache file (${data.length} bytes): $cachePath');
    int size = await ExternalStorage.saveBinary(data, cachePath);
    if (size != data.length) {
      nc.postNotification(NotificationNames.kPortableNetworkError, this, {
        'URL': pnf.url,
        'error': 'Failed to cache file',
      });
      // setStatus(PortableNetworkStatus.error);
      // return null;
    }
    if (_status == PortableNetworkStatus.decrypting) {
      nc.postNotification(NotificationNames.kPortableNetworkDecrypted, this, {
        'URL': pnf.url,
        'data': data,
        'path': cachePath,
      });
    }
    nc.postNotification(NotificationNames.kPortableNetworkSuccess, this, {
      'URL': pnf.url,
      'data': data,
    });
    setStatus(PortableNetworkStatus.success);
    return data;
  }

  Future<bool> _process() async {
    setStatus(PortableNetworkStatus.init);
    Uint8List? data;
    var nc = NotificationCenter();
    // 1. check cached file
    String? cachePath = await cacheFilePath;
    if (cachePath == null) {
      nc.postNotification(NotificationNames.kPortableNetworkError, this, {
        'URL': pnf.url,
        'error': 'Failed to get cache file path',
      });
      setStatus(PortableNetworkStatus.error);
      return false;
    }
    // try to load cached file
    if (await Paths.exists(cachePath)) {
      data = await ExternalStorage.loadBinary(cachePath);
      if (data != null && data.isNotEmpty) {
        // data loaded from cached file
        _bytes = data;
        nc.postNotification(NotificationNames.kPortableNetworkSuccess, this, {
          'URL': pnf.url,
          'data': data,
        });
        setStatus(PortableNetworkStatus.success);
        return true;
      }
    }
    // 2. check temporary file
    String? tmpPath = await temporaryFilePath;
    if (tmpPath == null) {
      nc.postNotification(NotificationNames.kPortableNetworkError, this, {
        'URL': pnf.url,
        'error': 'Failed to get temporary path',
      });
      setStatus(PortableNetworkStatus.error);
      return false;
    }
    // try to load temporary file
    if (await Paths.exists(tmpPath)) {
      data = await ExternalStorage.loadBinary(tmpPath);
      if (data != null && data.isNotEmpty) {
        // encrypted data loaded from temporary file
        // try to decrypt it
        data = await _decrypt(data, cachePath);
        return data != null;
      }
    }
    // 3. try to download
    Uri? url = pnf.url;
    if (url == null) {
      nc.postNotification(NotificationNames.kPortableNetworkError, this, {
        'URL': pnf.url,
        'error': 'URL not found',
      });
      setStatus(PortableNetworkStatus.error);
      return false;
    }
    setStatus(PortableNetworkStatus.downloading);
    data = await _HTTPHelper.download(url, onReceiveProgress: (count, total) {
      _count = count;
      _total = total;
      nc.postNotification(NotificationNames.kPortableNetworkReceiveProgress, this, {
        'URL': pnf.url,
        'count': count,
        'total': total,
      });
    });
    if (data == null || data.isEmpty) {
      nc.postNotification(NotificationNames.kPortableNetworkError, this, {
        'URL': pnf.url,
        'error': 'Failed to download file',
      });
      setStatus(PortableNetworkStatus.error);
      return false;
    }
    int cnt = await ExternalStorage.saveBinary(data, tmpPath);
    if (cnt == data.length) {
      nc.postNotification(NotificationNames.kPortableNetworkReceived, this, {
        'URL': pnf.url,
        'data': data,
        'path': tmpPath,
      });
    } else {
      nc.postNotification(NotificationNames.kPortableNetworkError, this, {
        'URL': pnf.url,
        'error': 'Failed to save temporary file',
      });
    }
    // encrypted data downloaded from remote URL
    // try to decrypt it
    data = await _decrypt(data, cachePath);
    return data != null;
  }

  Future<bool> run() async {
    Uint8List? data = _bytes;
    if (data == null) {
      data = pnf.data;
      if (data != null && data.isNotEmpty) {
        // assert(pnf.url == null, 'PNF error: $_pnf');
        // assert(_status == PortableNetworkStatus.init, 'PNF status: $_status');
        _bytes = data;
        // callback?.onSuccess(data, pnf);
        // setStatus(PortableNetworkStatus.success);
        return true;
      }
    } else {
      assert(data.isNotEmpty, 'file content error: $pnf');
      // assert(_status == PortableNetworkStatus.success, 'PNF status: $_status');
      return true;
    }
    bool ok;
    await lock.acquire();
    try {
      ok = await _process();
    } finally {
      lock.release();
    }
    return ok;
  }

  static final Mutex lock = Mutex();

}

class _FilenameUtils {

  static String filenameFromURL(Uri url, String? filename) {
    String? urlFilename = Paths.filename(url.toString());
    // check URL extension
    String? urlExt;
    if (urlFilename != null) {
      urlExt = Paths.extension(urlFilename);
      if (_isEncoded(urlFilename, urlExt)) {
        // URL filename already encoded
        return urlFilename;
      }
    }
    // check filename extension
    String? ext;
    if (filename != null) {
      ext = Paths.extension(filename);
      if (_isEncoded(filename, ext)) {
        // filename already encoded
        return filename;
      }
    }
    ext ??= urlExt;
    // get filename from URL
    Uint8List data = UTF8.encode(url.toString());
    filename = Hex.encode(MD5.digest(data));
    return ext == null || ext.isEmpty ? filename : '$filename.$ext';
  }

  // static String filenameFromData(Uint8List data, String filename) {
  //   // split file extension
  //   String? ext = Paths.extension(filename);
  //   if (_isEncoded(filename, ext)) {
  //     // already encoded
  //     return filename;
  //   }
  //   // get filename from data
  //   filename = Hex.encode(MD5.digest(data));
  //   return ext == null || ext.isEmpty ? filename : '$filename.$ext';
  // }

  static bool _isEncoded(String filename, String? ext) {
    if (ext != null && ext.isNotEmpty) {
      filename = filename.substring(0, filename.length - ext.length - 1);
    }
    return filename.length == 32 && _hex.hasMatch(filename);
  }
  static final _hex = RegExp(r'^[\dA-Fa-f]+$');

}

class _HTTPHelper {

  static String get userAgent {
    // return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
    //     ' AppleWebKit/537.36 (KHTML, like Gecko)'
    //     ' Chrome/118.0.0.0 Safari/537.36';
    GlobalVariable shared = GlobalVariable();
    return shared.terminal.userAgent;
  }

  static Future<Uint8List?> download(Uri url, {ProgressCallback? onReceiveProgress}) async {
    Response response;
    try {
      response = await Dio().getUri(url, onReceiveProgress: onReceiveProgress, options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': userAgent,
          }
      )).onError((error, stackTrace) {
        Log.error('[DIO] failed to download $url: $error');
        throw Exception(error);
      });
    } catch (e, st) {
      Log.error('failed to download $url: error: $e');
      Log.debug('failed to download $url: error: $e, $st');
      return null;
    }
    int? statusCode = response.statusCode;
    String? statusMessage = response.statusMessage;
    if (statusCode != 200) {
      Log.error('failed to download $url, status: $statusCode - $statusMessage');
      return null;
    }
    int? contentLength = getContentLength(response);
    Uint8List? data = response.data;
    if (data == null) {
      assert(contentLength == 0, 'content length error: $contentLength');
      return null;
    } else if (contentLength != null && contentLength != data.length) {
      assert(false, 'content length not match: $contentLength, ${data.length}');
      return null;
    }
    Log.info('downloaded ${data.length} byte(s) from: $url');
    return data;
  }

  static int? getContentLength(Response response) {
    String? value = response.headers.value(Headers.contentLengthHeader);
    return Converter.getInt(value, null);
  }

}
