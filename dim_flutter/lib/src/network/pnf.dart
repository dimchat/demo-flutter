import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mutex/mutex.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../client/shared.dart';
import '../filesys/external.dart';
import '../filesys/paths.dart';


///
///   PNF - Portable Network File
///


class PNFLoader {
  PNFLoader(this.pnf);

  // protected
  final PortableNetworkFile pnf;

  String? get cacheName => PNFHelper.getCacheName(pnf);

  String getCacheFilePath(String filename, String rootDirectory) {
    if (filename.length < 4) {
      assert(false, 'invalid filename: $filename');
      return Paths.append(rootDirectory, filename);
    }
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    return Paths.append(rootDirectory, aa, bb, filename);
  }

  Future<Uint8List?> download(String rootDirectory, {ProgressCallback? onReceiveProgress}) async {
    // 0. check pnf.data
    Uint8List? data = pnf.data;
    if (data != null) {
      Log.debug('PNF data exists: $pnf');
      return data;
    }
    String? path;
    // 1. check by 'filename'
    String? filename = pnf.filename;
    if (filename != null) {
      path = getCacheFilePath(filename, rootDirectory);
      if (await Paths.exists(path)) {
        Log.info('load cached image: $path for PNF: $pnf');
        return ExternalStorage.loadBinary(path);
      }
    }
    // 2. check by 'URL'
    Uri? url = pnf.url;
    if (url != null) {
      filename = PNFHelper.filenameFromURL(url, filename);
      if (filename != pnf.filename) {
        path = getCacheFilePath(filename, rootDirectory);
        if (await Paths.exists(path)) {
          Log.info('load cached image: $path for PNF: $pnf');
          return ExternalStorage.loadBinary(path);
        }
      }
    }
    // 3. try to download
    if (url == null || path == null) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    await _HTTPHelper.lock.acquire();
    try {
      data = await _HTTPHelper.download(url, onReceiveProgress: onReceiveProgress);
    } finally {
      _HTTPHelper.lock.release();
    }
    if (data == null) {
      Log.error('failed to download: $url => $path');
    } else {
      int size = await ExternalStorage.saveBinary(data, path);
      assert(size == data.length, 'failed to save file: ${data.length} -> $size bytes, $path');
      Log.info('saved $size byte(s) into: $path');
    }
    return data;
  }

}

class _HTTPHelper {

  static final Mutex lock = Mutex();

  static String get userAgent {
    // return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';
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

class PNFHelper {

  // static String? getExtension(PortableNetworkFile pnf) {
  //   // 1. check 'filename'
  //   String? filename = pnf.filename;
  //   if (filename == null) {
  //     // 2. check 'URL'
  //     Uri? url = pnf.url;
  //     if (url == null) {
  //       assert(false, 'PNF error: $pnf');
  //       return null;
  //     }
  //     filename = Paths.filename(url.toString());
  //     if (filename == null) {
  //       assert(false, 'URL error: $url');
  //       return null;
  //     }
  //   }
  //   // 3. get last level
  //   return Paths.extension(filename);
  // }

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
