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
import 'dart:math';
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:pnf/dos.dart';
import 'package:pnf/http.dart';

import '../common/constants.dart';
import '../filesys/local.dart';
import '../models/config.dart';


class FileUploader {
  factory FileUploader() => _instance;
  static final FileUploader _instance = FileUploader._internal();
  FileUploader._internal();

  bool _apiUpdated = false;

  String? _api;
  Uint8List? _secret;

  Future<void> _prepare() async {
    if (_apiUpdated) {
      return;
    }
    // config for upload
    Config config = Config();
    List api = await config.uploadAPI;
    String url;
    String enigma;
    // TODO: pick up the fastest API for upload
    var chosen = api[0];
    if (chosen is Map) {
      url = chosen['url'];
      enigma = chosen['enigma'];
    } else {
      assert(chosen is String, 'API error: $api');
      url = chosen;
      enigma = '';
    }
    if (url.isEmpty) {
      assert(false, 'config error: $api');
      return;
    }
    String? secret = await Enigma().getSecret(enigma);
    if (secret == null || secret.isEmpty) {
      assert(false, 'failed to get MD5 secret: $enigma');
      return;
    }
    Log.warning('setUploadConfig: $secret (enigma: $enigma), $url');
    await _setUploadConfig(api: url, secret: secret);
    _apiUpdated = true;
  }

  /// set upload API & secret key
  Future<void> _setUploadConfig({required String api, required String secret}) async {
    _api = api;
    _secret = Hex.decode(secret);
  }

  ///  Upload avatar image data for user
  ///
  /// @param data     - image data
  /// @param filename - image filename ('avatar.jpg')
  /// @param sender   - user ID
  /// @return remote URL if same file uploaded before
  /// @throws IOException on failed to create temporary file
  Future<Uri?> uploadAvatar(Uint8List data, String filename, ID sender) async {
    Uri? url = await _upload('avatar', data, filename, sender);
    String notification;
    if (url == null) {
      notification = NotificationNames.kFileUploadFailure;
    } else {
      notification = NotificationNames.kFileUploadSuccess;
    }
    // post notification async
    var nc = NotificationCenter();
    nc.postNotification(notification, this, {
      'filename': filename,
      'url': url,
    });
    return url;
  }

  ///  Upload encrypted file data for user
  ///
  /// @param data     - encrypted data
  /// @param filename - data file name ('voice.mp4')
  /// @param sender   - user ID
  /// @return remote URL if same file uploaded before
  /// @throws IOException on failed to create temporary file
  Future<Uri?> uploadEncryptData(Uint8List data, String filename, ID sender) async {
    Uri? url = await _upload('file', data, filename, sender);
    String notification;
    if (url == null) {
      notification = NotificationNames.kFileUploadFailure;
    } else {
      notification = NotificationNames.kFileUploadSuccess;
    }
    // post notification async
    var nc = NotificationCenter();
    nc.postNotification(notification, this, {
      'filename': filename,
      'url': url,
    });
    return url;
  }

  final Map<String, Uri> _uploads = {};    // filename => download url

  Future<Uri?> _upload(String varName, Uint8List data, String filename, ID sender) async {
    await _prepare();
    // 1. check old task
    Uri? url = _uploads[filename];
    if (url != null) {
      Log.info('this file had already been uploaded: $filename -> $url');
      return url;
    }
    // hash: md5(data + secret + salt)
    Uint8List secret = _secret!;
    Uint8List salt = _random(16);
    Uint8List hash = MD5.digest(_concat(data, secret, salt));
    // build task
    String urlString = _api!;
    Address address = sender.address;
    urlString = _replace(urlString, 'ID', address.toString());
    urlString = _replace(urlString, 'MD5', Hex.encode(hash));
    urlString = _replace(urlString, 'SALT', Hex.encode(salt));
    Log.info('upload encrypted data: $filename -> $urlString');
    FileTransfer ftp = FileTransfer();
    String? json = await ftp.uploadFile(Uri.parse(urlString), varName, filename, data);
    if (json == null) {
      Log.error('failed to upload file: $filename -> $urlString');
      return null;
    }
    Map? info = JSONMap.decode(json);
    int code = info?['code'];
    assert(code == 200, 'response error: $info');
    String? download = info?['url'];
    if (download == null) {
      return null;
    }
    Log.info('encrypted data uploaded: $filename -> $download');
    url = Uri.parse(download);
    _uploads[filename] = url;
    return url;
  }

  static Future<int> cacheFileData(Uint8List data, String filename) async {
    String? path = await _getCacheFilePath(filename);
    return await ExternalStorage.saveBinary(data, path);
  }

  static Future<String> _getCacheFilePath(String filename) async {
    if (filename.contains('/') || filename.contains('\\')) {
      // full path?
      return filename;
    } else {
      // relative path?
      LocalStorage cache = LocalStorage();
      return await cache.getCacheFilePath(filename);
    }
  }

}

String _replace(String template, String key, String value) =>
    template.replaceAll(RegExp('\\{$key\\}'), value);

Uint8List _concat(Uint8List a, Uint8List b, Uint8List c) =>
    Uint8List.fromList(a + b + c);

Uint8List _random(int size) {
  Uint8List data = Uint8List(size);
  Random r = Random();
  for (int i = 0; i < size; ++i) {
    data[i] = r.nextInt(256);
  }
  return data;
}
