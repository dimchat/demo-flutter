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

  String? get cacheName => _PNFHelper.getCacheName(pnf);

  String getCacheFilePath(String filename, String rootDirectory) {
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
    // 1. check by 'filename'
    String? filename = pnf.filename;
    String? path;
    if (filename != null) {
      path = getCacheFilePath(filename, rootDirectory);
      if (await Paths.exists(path)) {
        Log.info('load cached image: $path for PNF: $pnf');
        return ExternalStorage.loadBinary(path);
      }
    }
    // 2. check by 'URL'
    filename = _PNFHelper.getCacheName(pnf);
    if (filename != null && filename != pnf.filename) {
      path = getCacheFilePath(filename, rootDirectory);
      if (await Paths.exists(path)) {
        Log.info('load cached image: $path for PNF: $pnf');
        return ExternalStorage.loadBinary(path);
      }
    }
    // 3. try to download
    Uri? url = pnf.url;
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

  static final Dio dio = Dio();

  static String get userAgent {
    // return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';
    GlobalVariable shared = GlobalVariable();
    return shared.terminal.userAgent;
  }

  static Future<Uint8List?> download(Uri url, {ProgressCallback? onReceiveProgress}) async {
    Response response;
    try {
      response = await dio.getUri(url, onReceiveProgress: onReceiveProgress, options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'User-Agent': userAgent,
        }
      ));
    } on DioException catch (e) {
      Log.error('failed to download $url: $e');
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

class _PNFHelper {

  static String? getExtension(PortableNetworkFile pnf) {
    // 1. check 'filename'
    String? filename = pnf.filename;
    if (filename == null) {
      // 2. check 'URL'
      Uri? url = pnf.url;
      if (url == null) {
        assert(false, 'PNF error: $pnf');
        return null;
      }
      filename = Paths.filename(url.toString());
      if (filename == null) {
        assert(false, 'URL error: $url');
        return null;
      }
    }
    // 3. get last level
    return Paths.extension(filename);
  }

  /// cache filename for URL
  static String? getCacheName(PortableNetworkFile pnf) {
    String? name;
    // 1. get filename
    Uri? url = pnf.url;
    if (url != null) {
      name = Paths.filename(url.toString());
      name ??= pnf.filename;
    } else {
      name = pnf.filename;
    }
    if (name == null) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    // 2. get file extension
    String? ext = getExtension(pnf);
    if (ext == null) {
      assert(false, 'PNF error: $pnf');
      ext = '';
    }
    assert(name.isNotEmpty && ext.isNotEmpty, 'PNF error: $pnf');
    if (!name.endsWith('.$ext')) {
      Log.info('append file extension: $name + $ext');
      name += '.$ext';
    }
    // 3. check encode
    if (_isEncoded(name, ext)) {
      // already encoded
      return name;
    }
    // filename from data
    Uint8List data = UTF8.encode(url.toString());
    name = Hex.encode(MD5.digest(data));
    return ext.isEmpty ? name : '$name.$ext';
  }

  static bool _isEncoded(String filename, String ext) {
    if (ext.isNotEmpty) {
      filename = filename.substring(0, filename.length - ext.length - 1);
    }
    return filename.length == 32 && _hex.hasMatch(filename);
  }
  static final _hex = RegExp(r'^[\dA-Fa-f]+$');

}
