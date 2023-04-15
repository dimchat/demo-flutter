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
import 'dart:typed_data';

import 'paths.dart';

abstract class Readable {

  ///  Check file exists
  ///
  /// @param path - file path
  /// @return true on file exists
  Future<bool> exists(String path);

  ///  Read file content data
  ///
  /// @param path - file path
  /// @return file length
  /// @throws IOException on reading error
  Future<int> read(String path);

  ///  Get file content
  ///
  /// @return content data
  Uint8List? get data;
}

abstract class Writable implements Readable {

  ///  Set file content
  ///
  /// @param data - content data
  set data(Uint8List? content);

  ///  Write file content data
  ///
  /// @param path - file path
  /// @return file length
  /// @throws IOException on writing error
  Future<int> write(String path);

  ///  Delete file
  ///
  /// @param path - file path
  /// @return true on success
  /// @throws IOException on writing error
  Future<bool> remove(String path);
}

class Resource implements Readable {

  Uint8List? _content;

  @override
  Uint8List? get data => _content;

  @override
  Future<bool> exists(String path) async {
    return await Paths.exists(path);
  }

  @override
  Future<int> read(String path) async {
    File file = File(path);
    if (await file.exists()) {} else {
      // file not found
      throw Exception('failed to read file not exists: $path');
    }
    Uint8List bytes = await file.readAsBytes();
    _content = bytes;
    return bytes.length;
  }

}

class Storage extends Resource implements Writable {

  @override
  set data(Uint8List? content) => _content = content;

  @override
  Future<bool> remove(String path) async {
    if (await Paths.delete(path)) {
      return true;
    } else {
      throw Exception('failed to remove: $path');
    }
  }

  @override
  Future<int> write(String path) async {
    Uint8List? bytes = _content;
    if (bytes == null) {
      return -1;
    }
    File file = File(path);
    if (await file.exists()) {} else {
      // check parent directory exists
      Directory dir = file.parent;
      await dir.create(recursive: true);
      if (await dir.exists()) {} else {
        throw Exception('failed to create directory: ${dir.path}');
      }
    }
    await file.writeAsBytes(bytes, flush: true);
    return bytes.length;
  }

}
