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
import '../../channels/manager.dart';
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
    ChannelManager man = ChannelManager();
    return await man.ftpChannel.cachesDirectory;
  }

  ///  Protected temporary directory
  ///  (uploading, downloaded)
  ///
  /// Android: "/data/data/chat.dim.sechat/cache"
  ///     iOS: "/Application/{...}/tmp"
  Future<String> get temporaryDirectory async {
    ChannelManager man = ChannelManager();
    return await man.ftpChannel.temporaryDirectory;
  }

}
