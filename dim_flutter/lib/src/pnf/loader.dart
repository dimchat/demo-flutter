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
import 'package:pnf/dos.dart';
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
  Future<Uint8List?> get fileData async {
    String? path = await cacheFilePath;
    Uint8List? data = pnf.data;
    if (data == null || data.isEmpty) {
      // get from local storage
      if (path != null && await Paths.exists(path)) {
        data = await ExternalStorage.loadBinary(path);
      }
    } else if (path == null) {
      assert(false, 'failed to get file path: $pnf');
    } else {
      // save to local storage
      int cnt = await ExternalStorage.saveBinary(data, path);
      if (cnt == data.length) {
        // data saved, remove from message content
        pnf.data = null;
      } else {
        assert(false, 'failed to save data: $path');
      }
    }
    return data;
  }

  @override
  Future<void> postNotification(String name, [Map? info]) async {
    var nc = NotificationCenter();
    await nc.postNotification(name, this, info);
  }

  /// create upload task
  static Future<PortableFileUpper?> create(String api, PortableNetworkFile pnf, {
    required ID sender, required Enigma enigma,
  }) async {
    Uri? url = pnf.url;
    Uint8List? data = pnf.data;
    String? filename = pnf.filename;
    assert(url == null, 'remote URL already exists: $pnf');
    //
    //  1. check filename
    //
    if (filename == null) {
      Log.error('failed to create upload task: $pnf');
      assert(false, 'file content error: $pnf');
      return null;
    } else if (URLHelper.isFilenameEncoded(filename)) {
      // filename encoded: "md5(data).ext"
    } else if (data != null) {
      filename = URLHelper.filenameFromData(data, filename);
      Log.info('rebuild filename: ${pnf.filename} -> $filename');
      pnf.filename = filename;
    } else {
      // filename error
      assert(false, 'filename error: $pnf');
      return null;
    }
    //
    //  2. create with PNF
    //
    pnf['enigma'] = {
      'API': api,
      'sender': sender.toString(),
    };
    return PortableFileUpper(pnf, enigma);
  }

}
