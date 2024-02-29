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
import 'dart:io';

import 'package:path/path.dart' as utils;

import '../common/platform.dart';

class Paths {

  ///  Append all components to the path with separator
  ///
  /// @param path       - root directory
  /// @param components - sub-dir or filename
  /// @return new path
  static String append(String a, [String? b, String? c, String? d, String? e]) {
    return utils.join(a, b, c, d, e);
  }

  ///  Get filename from a URL/Path
  ///
  /// @param path - uri string
  /// @return filename
  static String? filename(String path) {
    return utils.basename(path);
  }

  ///  Get extension from a filename
  ///
  /// @param filename - file name
  /// @return file extension without '.'
  static String? extension(String filename) {
    String ext = utils.extension(filename);
    if (ext.isEmpty) {
      return null;
    } else if (ext.startsWith('.')) {
      return ext.substring(1);
    } else {
      return ext;
    }
  }

  ///  Get parent directory
  ///
  /// @param path - full path
  /// @return parent path
  static String? parent(String path) {
    return utils.dirname(path);
  }

  ///  Get absolute path
  ///
  /// @param relative - relative path
  /// @param base     - base directory
  /// @return absolute path
  static String abs(String relative, {required String base}) {
    if (relative.startsWith('/') || relative.indexOf(':') > 0) {
      // Linux   - "/filename"
      // Windows - "C:\\filename"
      // URL     - "file://filename"
      return relative;
    }
    String path;
    if (base.endsWith('/') || base.endsWith('\\')) {
      path = base + relative;
    } else {
      String separator = base.contains('\\') ? '\\' : '/';
      path = base + separator + relative;
    }
    if (path.contains('./')) {
      return tidy(path, separator: '/');
    } else if (path.contains('.\\')) {
      return tidy(path, separator: '\\');
    } else {
      return path;
    }
  }

  ///  Remove relative components in full path
  ///
  /// @param path      - full path
  /// @param separator - file separator
  /// @return absolute path
  static String tidy(String path, {required String separator}) {
    path = utils.normalize(path);
    if (separator == '/' && path.contains('\\')) {
      path = path.replaceAll('\\', '/');
    }
    return path;
  }

  //
  //  Read
  //

  ///  Check whether file exists
  ///
  /// @param path - file path
  /// @return true on exists
  static Future<bool> exists(String path) async {
    if (DevicePlatform.isWeb) {
      return true;
    }
    File file = File(path);
    return await file.exists();
  }

  //
  //  Write
  //

  ///  Create directory
  ///
  /// @param path - dir path
  /// @return false on error
  static Future<bool> mkdirs(String path) async {
    if (DevicePlatform.isWeb) {
      return true;
    }
    Directory dir = Directory(path);
    await dir.create(recursive: true);
    return await dir.exists();
  }

  ///  Delete file
  ///
  /// @param path - file path
  /// @return false on error
  static Future<bool> delete(String path) async {
    if (DevicePlatform.isWeb) {
      return true;
    }
    File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  }

}
