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

import 'package:mutex/mutex.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../common/constants.dart';
import '../filesys/external.dart';
import '../filesys/paths.dart';

import 'http.dart';

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
    return url == null ? name : URLHelper.filenameFromURL(url, name);
  }

  Future<Uint8List?> _decrypt(Uint8List data, String cachePath) async {
    var nc = NotificationCenter();
    //
    //  1. check password
    //
    DecryptKey? password = pnf.password;
    if (password == null) {
      // password not found, means the data is not encrypted
      _bytes = data;
    } else {
      setStatus(PortableNetworkStatus.decrypting);
      // try to decrypt with password
      Uint8List? plaintext = password.decrypt(data, pnf);
      if (plaintext == null || plaintext.isEmpty) {
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
    //
    //  2. save original file content
    //
    Log.info('[PNF] saving file (${data.length} bytes) into caches: $cachePath');
    int cnt = await ExternalStorage.saveBinary(data, cachePath);
    if (cnt != data.length) {
      // setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to cache file: $cnt/${data.length}, $cachePath');
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
    //
    //  1. check cached file
    //
    String? cachePath = await cacheFilePath;
    if (cachePath == null) {
      setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get cache file path');
      return false;
    }
    // try to load cached file
    if (await Paths.exists(cachePath)) {
      data = await ExternalStorage.loadBinary(cachePath);
      if (data != null && data.isNotEmpty) {
        // data loaded from cached file
        Log.info('[PNF] loaded ${data.length} bytes from caches: $cachePath');
        _bytes = data;
        nc.postNotification(NotificationNames.kPortableNetworkSuccess, this, {
          'URL': pnf.url,
          'data': data,
        });
        setStatus(PortableNetworkStatus.success);
        return true;
      }
    }
    //
    //  2. check temporary file
    //
    String? tmpPath = await temporaryFilePath;
    if (tmpPath == null) {
      setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get temporary path');
      return false;
    }
    // try to load temporary file
    if (await Paths.exists(tmpPath)) {
      data = await ExternalStorage.loadBinary(tmpPath);
      if (data != null && data.isNotEmpty) {
        // data loaded from temporary file
        Log.info('[PNF] loaded ${data.length} bytes from tmp: $tmpPath');
        // encrypted data loaded from temporary file
        // try to decrypt it
        data = await _decrypt(data, cachePath);
        return data != null;
      }
    }
    //
    //  3. download from remote URL
    //
    Uri? url = pnf.url;
    if (url == null) {
      setStatus(PortableNetworkStatus.error);
      assert(false, 'URL not found: $pnf');
      return false;
    }
    setStatus(PortableNetworkStatus.downloading);
    data = await HTTPHelper.download(url, onReceiveProgress: (count, total) {
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
    //
    //  4. save data from remote URL
    //
    Log.info('[PNF] saving file (${data.length} bytes) into tmp: $tmpPath');
    int cnt = await ExternalStorage.saveBinary(data, tmpPath);
    if (cnt != data.length) {
      // setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to save temporary file: $cnt/${data.length}, $tmpPath');
      // return false;
    }
    nc.postNotification(NotificationNames.kPortableNetworkReceived, this, {
      'URL': pnf.url,
      'data': data,
      'path': tmpPath,
    });
    //
    //  5. decrypt data from remote URL
    //
    data = await _decrypt(data, cachePath);
    return data != null;
  }

  Future<bool> run() async {
    Uint8List? data = _bytes;
    if (data == null) {
      data = pnf.data;
      if (data != null && data.isNotEmpty) {
        assert(pnf.url == null, 'PNF error: $pnf');
        // assert(_status == PortableNetworkStatus.init, 'PNF status: $_status');
        _bytes = data;
        var nc = NotificationCenter();
        nc.postNotification(NotificationNames.kPortableNetworkSuccess, this, {
          // 'URL': pnf.url,
          'data': data,
        });
        setStatus(PortableNetworkStatus.success);
        return true;
      }
    } else {
      assert(data.isNotEmpty, 'file content error: $pnf');
      // assert(_status == PortableNetworkStatus.success, 'PNF status: $_status');
      return true;
    }
    bool ok;
    await _lock.acquire();
    try {
      if (_bytes == null) {
        ok = await _process();
      } else {
        ok = true;
      }
    } finally {
      _lock.release();
    }
    return ok;
  }

  static final Mutex _lock = Mutex();

}
