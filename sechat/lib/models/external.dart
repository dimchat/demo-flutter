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

import '../client/filesys/paths.dart';
import '../client/filesys/resource.dart';

///  RAM access
abstract class ExternalStorage {

  ///  Forbid the gallery from scanning media files
  ///
  /// @param dir - data directory
  /// @return true on success
  static Future<bool> setNoMedia(String dir) async {
    if (Platform.isAndroid) {
      Log.debug('Forbid the gallery from scanning media files');
      String path = Paths.append(dir, '.nomedia');
      if (await Paths.exists(path)) {
        // already exists
        return true;
      }
      Storage file = Storage();
      file.data = UTF8.encode(promise);
      return await file.write(path) > 0;
    } else {
      Log.warning('TODO: Forbid the gallery from scanning media files');
      return false;
    }
  }
  static const String promise = 'Moky loves May Lee forever!';

  ///  Delete expired files in this directory cyclically
  ///
  /// @param dir     - directory
  /// @param expired - expired time (milliseconds, from Jan 1, 1970 UTC)
  static Future<void> cleanup(String dir, int expired, {bool recursive = true}) async {
    if (await FileSystemEntity.isDirectory(dir)) {
      _cleanDir(Directory(dir), expired, recursive);
    } else {
      Log.error('directory error: $dir');
    }
  }
  static Future<void> _cleanDir(Directory dir, int expired, bool recursive) async {
    // get all entities in this directory, let links be links
    List<FileSystemEntity> array = dir.listSync(followLinks: false);
    for (FileSystemEntity item in array) {
      if (item is Directory) {
        // sub directory
        if (recursive) {
          await _cleanDir(item, expired, true);
        } else {
          Log.warning('ignore sub directory: $item');
        }
      } else if (item is File) {
        // regular file
        await _cleanFile(item, expired);
      } if (item is Link) {
        // symbol link
        _cleanLink(item, expired, recursive);
      } else {
        // others?
        Log.error('unknown entity: $item');
      }
    }
  }
  static Future<void> _cleanFile(File file, int expired) async {
    FileStat stat = await file.stat();
    DateTime last = stat.modified;
    if (last.millisecondsSinceEpoch < expired) {
      Log.debug('cleaning expired file: $last, $file');
    }
  }
  static Future<void> _cleanLink(Link link, int expired, bool recursive) async {
    Log.warning('ignore link: $link');
  }

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
  static Future<Uint8List> loadBinary(String path) async {
    Uint8List? data = await _load(path);
    if (data == null) {
      throw Exception('failed to load binary file: $path');
    }
    return data;
  }

  ///  Load text from file path
  ///
  /// @param path - file path
  /// @return text string
  static Future<String> loadText(String path) async {
    Uint8List? data = await _load(path);
    if (data == null) {
      throw Exception('failed to load text file: $path');
    }
    String? text = UTF8.decode(data);
    return text!;
  }

  ///  Load JSON from file path
  ///
  /// @param path - file path
  /// @return Map/List object
  static Future<dynamic> loadJson(String path) async {
    Uint8List? data = await _load(path);
    if (data == null) {
      throw Exception('failed to load JSON file: $path');
    }
    String? text = UTF8.decode(data);
    return JSON.decode(text!);
  }

  //-------- write

  static Future<int> _save(Uint8List data, String path) async {
    Storage file = Storage();
    file.data = data;
    return await file.write(path);
  }

  ///  Save data into binary file
  ///
  /// @param data - binary data
  /// @param path - file path
  /// @return true on success
  static Future<int> saveBinary(Uint8List data, String path) async {
    int len = await _save(data, path);
    if (len != data.length) {
      throw Exception('failed to save binary file: $path');
    }
    return len;
  }

  ///  Save string into Text file
  ///
  /// @param text - text string
  /// @param path - file path
  /// @return true on success
  static Future<int> saveText(String text, String path) async {
    Uint8List data = UTF8.encode(text);
    int len = await _save(data, path);
    if (len != data.length) {
      throw Exception('failed to save text file: $path');
    }
    return len;
  }

  ///  Save Map/List into JSON file
  ///
  /// @param container - Map/List object
  /// @param path - file path
  /// @return true on success
  static Future<int> saveJson(Object container, String path) async {
    String text = JSON.encode(container);
    Uint8List data = UTF8.encode(text);
    int len = await _save(data, path);
    if (len != data.length) {
      throw Exception('failed to save json file: $path');
    }
    return len;
  }

}
