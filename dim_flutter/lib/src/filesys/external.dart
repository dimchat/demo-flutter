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

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import 'resource.dart';

///  RAM access
abstract class ExternalStorage {

  //-------- read

  static Future<Uint8List?> _load(String path) async {
    Storage file = Storage();
    if (await file.read(path) < 0) {
      return null;
    }
    return file.data;
  }

  ///  Load binary data from file
  ///
  /// @param path - file path
  /// @return file data
  static Future<Uint8List?> loadBinary(String path) async =>
      await _load(path);

  ///  Load text from file path
  ///
  /// @param path - file path
  /// @return text string
  static Future<String?> loadText(String path) async {
    Uint8List? data = await _load(path);
    if (data == null) {
      return null;
    }
    String? text = UTF8.decode(data);
    assert(text != null, 'Text file error: $path, size: ${data.length}');
    return text;
  }

  ///  Load JSON from file path
  ///
  /// @param path - file path
  /// @return Map/List object
  static Future<dynamic> loadJson(String path) async {
    Uint8List? data = await _load(path);
    if (data == null) {
      return null;
    }
    String? text = UTF8.decode(data);
    if (text == null) {
      assert(false, 'JsON file error: $path, size: ${data.length}');
      return null;
    }
    return JSON.decode(text);
  }
  static Future<Map?> loadJsonMap(String path) async =>
      await loadJson(path);
  static Future<List?> loadJsonList(String path) async =>
      await loadJson(path);

  //-------- write

  static Future<int> _save(Uint8List data, String path) async {
    Storage file = Storage();
    file.data = data;
    try {
      return await file.write(path);
    } catch (e) {
      return -1;
    }
  }

  ///  Save data into binary file
  ///
  /// @param data - binary data
  /// @param path - file path
  /// @return true on success
  static Future<int> saveBinary(Uint8List data, String path) async =>
      await _save(data, path);

  ///  Save string into Text file
  ///
  /// @param text - text string
  /// @param path - file path
  /// @return true on success
  static Future<int> saveText(String text, String path) async {
    Uint8List data = UTF8.encode(text);
    return await _save(data, path);
  }

  ///  Save Map/List into JSON file
  ///
  /// @param container - Map/List object
  /// @param path - file path
  /// @return true on success
  static Future<int> saveJson(Object container, String path) async {
    String text = JSON.encode(container);
    Uint8List data = UTF8.encode(text);
    return await _save(data, path);
  }
  static Future<int> saveJsonMap(Map container, String path) async =>
      await saveJson(container, path);
  static Future<int> saveJsonList(List container, String path) async =>
      await saveJson(container, path);

  ///  Clean expired files recursively
  ///
  /// @param dir - root directory
  /// @param expired - expired time
  /// @return number of removed files
  static Future<int> cleanupDirectory(Directory dir, DateTime expired) async {
    int total = 0;
    var files = dir.listSync();
    for (var item in files) {
      // directories, files, and links
      // does not include the special entries `'.'` and `'..'`.
      if (item is Directory) {
        total += await cleanupDirectory(item, expired);
      } else if (item is! File) {
        Log.warning('ignore link: $item');
      } else if (await cleanupFile(item, expired)) {
        total += 1;
      }
    }
    return total;
  }
  static Future<bool> cleanupFile(File file, DateTime expired) async {
    DateTime last = file.lastModifiedSync();
    if (last.isAfter(expired)) {
      return false;
    } else {
      Log.warning('removing expired file: $file, $last < $expired');
      file.delete().onError((error, stackTrace) {
        Log.error('failed to delete file: $file, $error, $stackTrace');
        return file;
      });
      return true;
    }
  }

}
