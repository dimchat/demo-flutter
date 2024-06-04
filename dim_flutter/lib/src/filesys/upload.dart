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
import 'package:dim_client/dim_client.dart';
import 'package:flutter/services.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:pnf/dos.dart';
import 'package:pnf/enigma.dart';
import 'package:pnf/http.dart';

import '../client/shared.dart';
import '../common/constants.dart';
import '../models/config.dart';

import 'local.dart';


class FileUploader {
  factory FileUploader() => _instance;
  static final FileUploader _instance = FileUploader._internal();
  FileUploader._internal() {
    _ftp = FileTransfer(HTTPClient());
    _enigma = Enigma();
  }

  late final FileTransfer _ftp;
  late final Enigma _enigma;

  bool _apiUpdated = false;

  String? _api;

  //  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
  //  + ' AppleWebKit/537.36 (KHTML, like Gecko)'
  //  + ' Chrome/118.0.0.0 Safari/537.36'
  void setUserAgent(String userAgent) =>
      _ftp.setUserAgent(userAgent);

  /// Append download task with URL
  Future<bool> addDownloadTask(DownloadTask task) async {
    await _prepare();
    return await _ftp.addDownloadTask(task);
  }

  /// Upload a file to URL
  ///
  /// @return response text
  Future<String?> uploadFile(Uri url, String key, String filename, Uint8List fileData) async =>
      _ftp.uploadFile(url, key, filename, fileData);

  /// Update secrets
  bool updateSecrets(dynamic secrets) {
    if (secrets == null) {
      return false;
    }
    Log.info('set enigma secrets: $secrets');
    List<String> lines = [];
    for (var element in secrets) {
      if (element is String && element.isNotEmpty) {
        lines.add(element);
      }
    }
    _enigma.update(lines);
    return lines.isNotEmpty;
  }

  /// Get enigma secret for this API
  Pair<String, Uint8List>? fetchEnigma(String api) =>
      _enigma.fetch(api);

  /// Build upload URL
  String buildURL(String api, ID sender,
      {required Uint8List data, required Uint8List secret, required String enigma}) =>
      _enigma.build(api, sender, data: data, secret: secret, enigma: enigma);

  Future<void> _prepare() async {
    if (_apiUpdated) {
      return;
    }
    //
    //  0. set user agent
    //
    GlobalVariable shared = GlobalVariable();
    String ua = shared.terminal.userAgent;
    Log.info('update user-agent: $ua');
    _ftp.setUserAgent(ua);
    //
    //  1. load enigma secrets
    //
    String json = await rootBundle.loadString('assets/enigma.json');
    Map? info = JSONMap.decode(json);
    bool ok = updateSecrets(info?['secrets']);
    assert(ok, 'failed to update enigma secrets: $json');
    //
    //  2. config for upload API
    //
    Config config = Config();
    List apiList = await config.uploadAPI;
    String url = '';
    String? enigma;
    // TODO: pick up the fastest API for upload
    for (var api in apiList) {
      if (api is Map) {
        url = api['url'];
        enigma = api['enigma'];
        if (enigma != null) {
          url = '$url&enigma=$enigma';
        }
      } else {
        assert(api is String, 'API error: $api');
        url = api;
        enigma = '';
      }
      if (url.isEmpty) {
        Log.info('skip this API: $api');
        continue;
      }
      Log.info('got upload API: $api');
      break;
    }
    Log.warning('set upload API: $url (enigma: $enigma)');
    _api = url;
    _apiUpdated = true;
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
    String? api = _api;
    if (api == null || api.isEmpty) {
      assert(false, 'failed to get upload API');
      return null;
    }
    Pair<String, Uint8List>? pair = fetchEnigma(api);
    if (pair == null) {
      assert(false, 'failed to fetch enigma: $api');
      return null;
    }
    String enigma = pair.first;
    Uint8List secret = pair.second;
    String urlString = buildURL(api, sender, data: data, secret: secret, enigma: enigma);
    Log.info('upload encrypted data: $filename (enigma: $enigma) -> $urlString');
    String? json = await uploadFile(Uri.parse(urlString), varName, filename, data);
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
