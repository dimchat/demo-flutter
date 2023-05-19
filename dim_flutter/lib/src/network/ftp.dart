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
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../client/constants.dart';
import '../filesys/external.dart';
import '../filesys/local.dart';
import '../filesys/paths.dart';
import '../widgets/browser.dart';

class FileTransfer {
  factory FileTransfer() => _instance;
  static final FileTransfer _instance = FileTransfer._internal();
  FileTransfer._internal();

  ///  Upload avatar image data for user
  ///
  /// @param data     - image data
  /// @param filename - image filename ('avatar.jpg')
  /// @param sender   - user ID
  /// @return remote URL if same file uploaded before
  /// @throws IOException on failed to create temporary file
  Future<Uri?> uploadAvatar(Uint8List data, String filename, ID sender) async {
    ChannelManager man = ChannelManager();
    return await man.ftpChannel.uploadAvatar(data, filename, sender);
  }

  ///  Upload encrypted file data for user
  ///
  /// @param data     - encrypted data
  /// @param filename - data file name ('voice.mp4')
  /// @param sender   - user ID
  /// @return remote URL if same file uploaded before
  /// @throws IOException on failed to create temporary file
  Future<Uri?> uploadEncryptData(Uint8List data, String filename, ID sender) async {
    ChannelManager man = ChannelManager();
    return await man.ftpChannel.uploadEncryptData(data, filename, sender);
  }

  static bool _isEncoded(String filename, String? ext) {
    if (ext != null && ext.isNotEmpty) {
      filename = filename.substring(0, filename.length - ext.length - 1);
    }
    if (filename.length != 32) {
      return false;
    }
    return filename.replaceAll('[0-9A-Fa-f]+', '').isEmpty;
  }

  static String filenameFromData(Uint8List data, String filename) {
    // split file extension
    String? ext = Paths.extension(filename);
    if (_isEncoded(filename, ext)) {
      // already encoded
      return filename;
    } else {
      // get filename from data
      filename = Hex.encode(MD5.digest(data));
      return ext == null || ext.isEmpty ? filename : '$filename.$ext';
    }
  }

  //
  //  Decryption process
  //  ~~~~~~~~~~~~~~~~~~
  //
  //  1. get 'filename' from file content and call 'getCacheFilePath(filename)',
  //     if not null, means this file is already downloaded an decrypted;
  //
  //  2. get 'URL' from file content and call 'downloadEncryptedFile(url)',
  //     if not null, means this file is already downloaded but not decrypted yet,
  //     this step will get a temporary path for encrypted data, continue step 3;
  //     if the return path is null, then let the delegate waiting for response;
  //
  //  3. get 'password' from file content and call 'decryptFileData(path, password)',
  //     this step will get the decrypted file data, you should save it to cache path
  //     by calling 'cacheFileData(data, filename)', notice that this filename is in
  //     hex format by hex(md5(data)), which is the same string with content.filename.
  //

  Future<String?> getFilePath(FileContent content) async {
    String? filename = content.filename;
    if (filename == null) {
      Log.error('file content error: $content');
      return null;
    }
    // check decrypted file
    String cachePath = await _getCacheFilePath(filename);
    if (await Paths.exists(cachePath)) {
      return cachePath;
    }
    // get download URL
    String? urlString = content.url;
    if (urlString == null) {
      Log.error('file URL not found: $content');
      return null;
    }
    Uri? url = Browser.parseUri(urlString);
    if (url == null) {
      Log.error('URL error: $urlString');
      return null;
    }
    // try download file from remote URL
    String? tempPath = await _downloadEncryptedFile(url);
    if (tempPath == null) {
      Log.info('not download yet: $url');
      // TODO: post notification?
      return null;
    }
    // decrypt with message password
    DecryptKey? password = content.password;
    if (password == null) {
      Log.error('password not found: $content');
      return null;
    }
    Uint8List? data = await _decryptFileData(tempPath, password);
    if (data == null) {
      Log.error('failed to decrypt file: $tempPath, password: $password');
      // delete to download again
      await Paths.delete(tempPath);
      return null;
    }
    // save decrypted file data
    int len = await cacheFileData(data, cachePath);
    if (len == data.length) {
      Log.info('store decrypted file data: $filename -> $url => $cachePath');
    } else {
      Log.error('failed to cache file: $cachePath');
      return null;
    }
    // post notification async
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kFileDownloadSuccess, this, {
      'url': url,
      'path': cachePath,
    });
    // success
    return cachePath;
  }

  ///  Download avatar image file
  ///
  /// @param url      - avatar URL
  /// @return local path if same file downloaded before
  Future<String?> downloadAvatar(Uri url) async {
    ChannelManager man = ChannelManager();
    String? path = await man.ftpChannel.downloadAvatar(url);
    String notification;
    if (path == null) {
      notification = NotificationNames.kFileDownloadFailure;
    } else {
      notification = NotificationNames.kFileDownloadSuccess;
    }
    // post notification async
    var nc = NotificationCenter();
    nc.postNotification(notification, this, {
      'url': url,
      'path': path,
    });
    return path;
  }

  ///  Download encrypted file data for user
  ///
  /// @param url      - relay URL
  /// @return temporary path if same file downloaded before
  Future<String?> _downloadEncryptedFile(Uri url) async {
    ChannelManager man = ChannelManager();
    return await man.ftpChannel.downloadFile(url);
  }

  ///  Decrypt temporary file with password from received message
  ///
  /// @param path     - temporary path
  /// @param password - symmetric key
  /// @return decrypted data
  static Future<Uint8List?> _decryptFileData(String path, DecryptKey password) async {
    Uint8List? data = await _loadDownloadedFileData(path);
    if (data == null) {
      Log.warning('failed to load temporary file: $path');
      return null;
    }
    Log.info('decrypting file: $path, size: ${data.length}');
    try {
      return password.decrypt(data);
    } catch (e) {
      Log.error('failed to decrypt file data: $path, $password');
      return null;
    }
  }

  static Future<Uint8List?> _loadDownloadedFileData(String filename) async {
    String path = await _getDownloadFilePath(filename);
    if (await Paths.exists(path)) {
      return await ExternalStorage.loadBinary(path);
    }
    return null;
  }

  static Future<int> cacheFileData(Uint8List data, String filename) async {
    String path = await _getCacheFilePath(filename);
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

  static Future<String> _getDownloadFilePath(String filename) async {
    if (filename.contains('/') || filename.contains('\\')) {
      // full path?
      return filename;
    } else {
      // relative path?
      LocalStorage cache = LocalStorage();
      return await cache.getDownloadFilePath(filename);
    }
  }

  ///  Get entity file path: "/sdcard/chat.dim.sechat/mkm/{AA}/{BB}/{address}/{filename}"
  ///
  /// @param entity   - user or group ID
  /// @param filename - entity file name
  /// @return entity file path
  Future<String> getEntityFilePath(ID entity, String filename) async {
    String dir = await _getEntityDirectory(entity.address);
    return Paths.append(dir, filename);
  }

  Future<String> _getEntityDirectory(Address address) async {
    LocalStorage cache = LocalStorage();
    String dir = Paths.append(await cache.cachesDirectory, 'mkm');
    String string = address.toString();
    String aa = string.substring(0, 2);
    String bb = string.substring(2, 4);
    return Paths.append(dir, aa, bb, string);
  }

}
