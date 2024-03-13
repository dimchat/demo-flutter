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
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';

import '../channels/manager.dart';
import '../common/constants.dart';
import '../filesys/external.dart';
import '../filesys/local.dart';


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

  static Future<int> cacheFileData(Uint8List data, String filename) async {
    String? path = await _getCacheFilePath(filename);
    if (path == null) {
      Log.error('failed to get caches directory for saving: $filename');
      return -1;
    }
    return await ExternalStorage.saveBinary(data, path);
  }

  static Future<String?> _getCacheFilePath(String filename) async {
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
