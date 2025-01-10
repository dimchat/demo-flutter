/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:pnf/enigma.dart';
import 'package:pnf/pnf.dart';

import '../filesys/local.dart';

class PortableFileLoader extends PortableNetworkLoader {
  PortableFileLoader(super.pnf);

  @override
  FileCache get fileCache => LocalStorage();

  @override
  Future<void> postNotification(String name, [Map? info]) async {
    var nc = NotificationCenter();
    await nc.postNotification(name, this, info);
  }

}


class PortableFileUpper extends PortableNetworkUpper {
  PortableFileUpper(super.pnf, this._enigma);

  final Enigma _enigma;

  @override
  Enigma get enigma => _enigma;

  @override
  FileCache get fileCache => LocalStorage();

  @override
  Future<void> postNotification(String name, [Map? info]) async {
    var nc = NotificationCenter();
    await nc.postNotification(name, this, info);
  }

  /// create upload task
  static Future<PortableFileUpper?> create(String api, PortableNetworkFile pnf, {
    required ID sender, required Enigma enigma,
  }) async {
    String? filename = pnf.filename;
    Uint8List? data = pnf.data;
    if (filename == null || data == null) {
      assert(false, 'file content error: $pnf');
      return null;
    }
    //
    //  1. rebuild filename
    //
    if (URLHelper.isFilenameEncoded(filename)) {} else {
      filename = URLHelper.filenameFromData(data, filename);
    }
    //
    //  2. cache file data
    //
    var fileCache = LocalStorage();
    String path = await fileCache.getCacheFilePath(filename);
    int cnt = await ExternalStorage.saveBinary(data, path);
    if (cnt != data.length) {
      Log.error('failed to save file data: $cnt/${data.length} bytes: $filename -> $path');
      return null;
    } else {
      // file data saved to cache file, remove it from content
      pnf.data = null;
      pnf.filename = filename;
    }
    //
    //  3. create with PNF
    //
    pnf['enigma'] = {
      'API': api,
      'sender': sender.toString(),
    };
    return PortableFileUpper(pnf, enigma);
  }

}
