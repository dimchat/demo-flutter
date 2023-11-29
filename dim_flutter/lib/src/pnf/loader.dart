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

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../common/constants.dart';
import '../filesys/external.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';

import 'http.dart';

enum PortableNetworkStatus {
  init,
  waiting,
  downloading,
  decrypting,
  success,
  error,
}

class PortableNetworkLoader implements DownloadTask {
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

  @override
  String toString() {
    Type clazz = runtimeType;
    Uri? url = pnf.url;
    if (url != null) {
      return '<$clazz URL="$url" />';
    }
    String? filename = pnf.filename;
    Uint8List? data = pnf.data;
    return '<$clazz filename="$filename" length="${data?.length}" />';
  }

  /// original filename
  String? get cacheFilename {
    String? name = pnf.filename;
    // get name from PNF
    if (name != null && URLHelper.isFilenameEncoded(name)) {
      return name;
    }
    // Log.debug('[PNF] filename error: $pnf');
    Uri? url = pnf.url;
    if (url != null) {
      return URLHelper.filenameFromURL(url, name);
    }
    assert(false, 'PNF error: $pnf');
    return name;
  }

  /// encrypted filename
  String? get temporaryFilename {
    String? name = pnf.filename;
    // get name from URL
    Uri? url = pnf.url;
    if (url != null) {
      return URLHelper.filenameFromURL(url, name);
    }
    assert(false, 'PNF error: $pnf');
    return name;
  }

  /// "{caches}/files/{AA}/{BB}/{filename}"
  Future<String?> get cacheFilePath async {
    String? name = cacheFilename;
    if (name == null || name.isEmpty) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    LocalStorage cache = LocalStorage();
    return await cache.getCacheFilePath(name);
  }

  /// "{tmp}/download/{filename}"
  Future<String?> get downloadFilePath async {
    String? name = temporaryFilename;
    if (name == null || name.isEmpty) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    LocalStorage cache = LocalStorage();
    return await cache.getDownloadFilePath(name);
  }
  /// "{tmp}/upload/{filename}"
  Future<String?> get uploadFilePath async {
    String? name = temporaryFilename;
    if (name == null || name.isEmpty) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    LocalStorage cache = LocalStorage();
    return await cache.getUploadFilePath(name);
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

  //
  //  DownloadTask
  //

  @override
  Future<Uri?> prepare() async {
    // setStatus(PortableNetworkStatus.init);
    var nc = NotificationCenter();
    //
    //  0. check file content
    //
    Uint8List? data = _bytes;
    if (data != null && data.isNotEmpty) {
      // data already loaded
      nc.postNotification(NotificationNames.kPortableNetworkSuccess, this, {
        'URL': pnf.url,
        'data': data,
      });
      setStatus(PortableNetworkStatus.success);
      return null;
    } else {
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
        return null;
      }
    }
    //
    //  1. check cached file
    //
    String? cachePath = await cacheFilePath;
    if (cachePath == null) {
      setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get cache file path');
      return null;
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
        return null;
      }
    }
    //
    //  2. check temporary file
    //
    String? tmpPath;
    String? down = await downloadFilePath;
    if (down != null && await Paths.exists(down)) {
      // file exists in download directory
      tmpPath = down;
    } else {
      String? up = await uploadFilePath;
      if (up != null && up != down && await Paths.exists(up)) {
        // file exists in upload directory
        tmpPath = up;
      }
    }
    if (tmpPath != null) {
      // try to load temporary file
      data = await ExternalStorage.loadBinary(tmpPath);
      if (data != null && data.isNotEmpty) {
        // data loaded from temporary file
        Log.info('[PNF] loaded ${data.length} bytes from tmp: $tmpPath');
        // encrypted data loaded from temporary file
        // try to decrypt it
        data = await _decrypt(data, cachePath);
        if (data != null && data.isNotEmpty) {
          return null;
        }
      }
    }
    //
    //  3. get remote URL
    //
    Uri? url = pnf.url;
    if (url == null) {
      setStatus(PortableNetworkStatus.error);
      assert(false, 'URL not found: $pnf');
    } else {
      setStatus(PortableNetworkStatus.waiting);
    }
    return url;
  }

  @override
  Future<void> progress(int count, int total, Uri url) async {
    _count = count;
    _total = total;
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kPortableNetworkReceiveProgress, this, {
      'URL': pnf.url,
      'count': count,
      'total': total,
    });
    setStatus(PortableNetworkStatus.downloading);
  }

  @override
  Future<void> process(Uint8List? data, Uri url) async {
    var nc = NotificationCenter();
    //
    //  0. check data
    //
    if (data == null || data.isEmpty) {
      nc.postNotification(NotificationNames.kPortableNetworkError, this, {
        'URL': pnf.url,
        'error': 'Failed to download file',
      });
      setStatus(PortableNetworkStatus.error);
      return;
    }
    //
    //  1.. save data from remote URL
    //
    String? tmpPath = await downloadFilePath;
    if (tmpPath == null) {
      setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get temporary path');
      return;
    }
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
    //  2. decrypt data from remote URL
    //
    String? cachePath = await cacheFilePath;
    if (cachePath == null) {
      setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get cache file path');
      return;
    }
    data = await _decrypt(data, cachePath);
  }

}
