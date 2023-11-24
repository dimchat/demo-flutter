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

import 'package:dio/dio.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../client/shared.dart';
import '../filesys/paths.dart';


class PNFHelper {

  /// cache filename for PNF
  static String? getCacheName(Map info) {
    PortableNetworkFile? pnf = PortableNetworkFile.parse(info);
    if (pnf == null) {
      assert(false, 'PNF error: $info');
      return null;
    }
    String? filename = pnf.filename;
    Uri? url = pnf.url;
    if (url == null) {
      return filename;
    } else {
      return filenameFromURL(url, filename);
    }
  }

  static String filenameFromURL(Uri url, String? filename) {
    String? urlFilename = Paths.filename(url.toString());
    // check URL extension
    String? urlExt;
    if (urlFilename != null) {
      urlExt = Paths.extension(urlFilename);
      if (_isEncoded(urlFilename, urlExt)) {
        // URL filename already encoded
        return urlFilename;
      }
    }
    // check filename extension
    String? ext;
    if (filename != null) {
      ext = Paths.extension(filename);
      if (_isEncoded(filename, ext)) {
        // filename already encoded
        return filename;
      }
    }
    ext ??= urlExt;
    // get filename from URL
    Uint8List data = UTF8.encode(url.toString());
    filename = Hex.encode(MD5.digest(data));
    return ext == null || ext.isEmpty ? filename : '$filename.$ext';
  }

  static String filenameFromData(Uint8List data, String filename) {
    // split file extension
    String? ext = Paths.extension(filename);
    if (_isEncoded(filename, ext)) {
      // already encoded
      return filename;
    }
    // get filename from data
    filename = Hex.encode(MD5.digest(data));
    return ext == null || ext.isEmpty ? filename : '$filename.$ext';
  }

  static bool _isEncoded(String filename, String? ext) {
    if (ext != null && ext.isNotEmpty) {
      filename = filename.substring(0, filename.length - ext.length - 1);
    }
    return filename.length == 32 && _hex.hasMatch(filename);
  }
  static final _hex = RegExp(r'^[\dA-Fa-f]+$');

}


class HTTPHelper {

  static String get userAgent {
    // return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
    //     ' AppleWebKit/537.36 (KHTML, like Gecko)'
    //     ' Chrome/118.0.0.0 Safari/537.36';
    GlobalVariable shared = GlobalVariable();
    return shared.terminal.userAgent;
  }

  static Future<Uint8List?> download(Uri url, {ProgressCallback? onReceiveProgress}) async {
    Response response;
    try {
      response = await Dio().getUri(url, onReceiveProgress: onReceiveProgress, options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': userAgent,
          }
      )).onError((error, stackTrace) {
        Log.error('[DIO] failed to download $url: $error');
        throw Exception(error);
      });
    } catch (e, st) {
      Log.error('failed to download $url: error: $e');
      Log.debug('failed to download $url: error: $e, $st');
      return null;
    }
    int? statusCode = response.statusCode;
    String? statusMessage = response.statusMessage;
    if (statusCode != 200) {
      Log.error('failed to download $url, status: $statusCode - $statusMessage');
      return null;
    }
    int? contentLength = getContentLength(response);
    Uint8List? data = response.data;
    if (data == null) {
      assert(contentLength == 0, 'content length error: $contentLength');
      return null;
    } else if (contentLength != null && contentLength != data.length) {
      assert(false, 'content length not match: $contentLength, ${data.length}');
      return null;
    }
    Log.info('downloaded ${data.length} byte(s) from: $url');
    return data;
  }

  static int? getContentLength(Response response) {
    String? value = response.headers.value(Headers.contentLengthHeader);
    return Converter.getInt(value, null);
  }

}
