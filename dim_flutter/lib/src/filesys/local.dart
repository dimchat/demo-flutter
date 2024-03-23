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
import 'package:path_provider/path_provider.dart';

import 'package:lnc/log.dart';
import 'package:pnf/dos.dart';

import '../channels/manager.dart';
import '../common/platform.dart';

class LocalStorage extends FileCache with Logging {
  factory LocalStorage() => _instance;
  static final LocalStorage _instance = LocalStorage._internal();
  LocalStorage._internal();

  @override
  Future<String> get cachesDirectory async {
    if (DevicePlatform.isWeb) {
      return '/var/caches';
    }
    if (DevicePlatform.isIOS || DevicePlatform.isAndroid) {
      ChannelManager man = ChannelManager();
      String? path = await man.ftpChannel.cachesDirectory;
      // logInfo('[DOS] caches directory: $path');
      return path!;
    }
    var dir = await getApplicationSupportDirectory();
    // logInfo('[DOS] caches directory: $dir');
    return dir.path;
  }

  @override
  Future<String> get temporaryDirectory async {
    if (DevicePlatform.isWeb) {
      return '/tmp';
    }
    if (DevicePlatform.isIOS || DevicePlatform.isAndroid) {
      ChannelManager man = ChannelManager();
      String? path = await man.ftpChannel.temporaryDirectory;
      // logInfo('[DOS] temporary directory: $path');
      return path!;
    }
    var dir = await getTemporaryDirectory();
    // logInfo('[DOS] temporary directory: $dir');
    return dir.path;
  }

  ///  Avatar image file path
  ///
  /// @param filename - image filename: hex(md5(data)) + ext
  /// @return "{caches}/avatar/{AA}/{BB}/{filename}"
  Future<String> getAvatarFilePath(String filename) async {
    if (filename.indexOf('.') < 4) {
      assert(false, 'invalid filename: $filename');
      return Paths.append(await cachesDirectory, filename);
    }
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    return Paths.append(await cachesDirectory, 'avatar', aa, bb, filename);
  }

}
