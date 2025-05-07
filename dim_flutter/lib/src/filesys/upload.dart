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
import 'dart:async';

import 'package:flutter/services.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:pnf/dos.dart';
import 'package:pnf/enigma.dart';
import 'package:pnf/http.dart';

import '../client/shared.dart';
import '../models/config.dart';
import '../pnf/loader.dart';

import 'local.dart';


class SharedFileUploader with Logging {
  factory SharedFileUploader() => _instance;
  static final SharedFileUploader _instance = SharedFileUploader._internal();
  SharedFileUploader._internal() {
    _ftp = FileTransfer(HTTPClient());
    _enigma = Enigma();
  }

  late final FileTransfer _ftp;
  late final Enigma _enigma;

  Enigma get enigma => _enigma;

  bool _secretsLoaded = false;

  String? _upAvatarAPI;
  String? _upFileAPI;

  //  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
  //  + ' AppleWebKit/537.36 (KHTML, like Gecko)'
  //  + ' Chrome/118.0.0.0 Safari/537.36'
  void setUserAgent(String userAgent) =>
      _ftp.setUserAgent(userAgent);

  /// Append download task with URL
  Future<bool> addDownloadTask(DownloadTask task) async {
    await _initSecrets();
    return await _ftp.addDownloadTask(task);
  }

  Future<bool> addUploadTask(UploadTask task) async {
    await _initSecrets();
    return await _ftp.addUploadTask(task);
  }

  Future<bool> _initSecrets() async {
    if (_secretsLoaded) {
      return false;
    } else {
      _secretsLoaded = true;
    }
    //
    //  1. set user agent
    //
    GlobalVariable shared = GlobalVariable();
    String ua = shared.terminal.userAgent;
    logInfo('update user-agent: $ua');
    _ftp.setUserAgent(ua);
    //
    //  2. load enigma secrets
    //
    String json = await rootBundle.loadString('assets/enigma.json');
    Map? info = JSONMap.decode(json);
    List? secrets = info?['secrets'];
    if (secrets == null) {
      assert(false, 'failed to update enigma secrets: $json');
      return false;
    }
    logInfo('set enigma secrets: $secrets');
    List<String> lines = [];
    for (var pwd in secrets) {
      if (pwd is String && pwd.isNotEmpty) {
        lines.add(pwd);
      }
    }
    _enigma.update(lines);
    return lines.isNotEmpty;
  }

  void initWithConfig(Config config) {
    String? api = config.uploadAvatarAPI;
    logInfo('set avatar API: $_upAvatarAPI -> $api');
    if (api != null) {
      _upAvatarAPI = api;
    }
    api = config.uploadFileAPI;
    logInfo('set file API: $_upFileAPI -> $api');
    if (api != null) {
      _upFileAPI = api;
    }
  }

  ///  Upload avatar image data for user
  ///
  /// @param data     - image data
  /// @param filename - image filename ('avatar.jpg')
  /// @param sender   - user ID
  /// @return null on failed
  Future<Uri?> uploadAvatar(Uint8List data, String filename, ID sender) async {
    String? api = _upAvatarAPI;
    if (api == null) {
      assert(false, 'avatar API not ready');
      return null;
    }
    // create upload task
    var pnf = PortableNetworkFile.createFromData(data, filename);
    pnf.password = PlainKey.getInstance();
    var task = await PortableFileUploadTask.create(api, pnf,
      sender: sender, enigma: _enigma,
    );
    if (task == null) {
      return null;
    }
    // handle upload task
    try {
      var uploader = _ftp.uploader;
      if (uploader is FileUploader) {
        await uploader.handleUploadTask(task);
      }
    } catch (e, st) {
      logError('[HTTP] failed to handle upload task: $task, error: $e, $st');
      return null;
    }
    // OK
    return pnf.url;
  }

  ///  Upload encrypted file data for user
  ///
  /// @param content - message content with filename & data
  /// @param sender  - user ID
  /// @return true on waiting upload
  Future<bool> uploadEncryptData(FileContent content, ID sender) async {
    String? api = _upFileAPI;
    if (api == null) {
      assert(false, 'file API not ready');
      return false;
    }
    var pnf = PortableNetworkFile.parse(content.toMap());
    if (pnf == null) {
      logError('file content error: $content');
      assert(false, 'file content error: $content');
      return false;
    }
    var task = await PortableFileUploadTask.create(api, pnf,
      sender: sender, enigma: _enigma,
    );
    if (task == null) {
      logError('failed to create upload task: $api, $sender');
      return false;
    }
    return await addUploadTask(task);
  }

  static Future<int> cacheFileData(Uint8List data, String filename) async {
    String? path = await _getCacheFilePath(filename);
    return await ExternalStorage.saveBinary(data, path);
  }

  static Future<Uint8List?> getFileData(String filename) async {
    String? path = await _getCacheFilePath(filename);
    return await ExternalStorage.loadBinary(path);
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
