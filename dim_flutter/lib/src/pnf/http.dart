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
import 'package:lnc/log.dart';

import '../client/shared.dart';
import '../filesys/paths.dart';
import 'loader.dart';


class URLHelper {

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

  static bool isFilenameEncoded(String filename) {
    String? ext = Paths.extension(filename);
    return _isEncoded(filename, ext);
  }

  static bool _isEncoded(String filename, String? ext) {
    if (ext != null/* && ext.isNotEmpty*/) {
      filename = filename.substring(0, filename.length - ext.length - 1);
    }
    return filename.length == 32 && _hex.hasMatch(filename);
  }
  static final _hex = RegExp(r'^[\dA-Fa-f]+$');

}

///
/// HTTP Downloader
///

abstract interface class DownloadTask {

  /// Prepare the task and get remote URL
  Future<Uri?> prepare();

  /// Callback when downloading
  Future<void> progress(int count, int total, Uri url);

  /// Callback when download completed or failed
  Future<void> process(Uint8List? data, Uri url);

}

abstract class Downloader {

  bool _running = false;

  final List<DownloadTask> _tasks = WeakList();

  void addTask(DownloadTask task) async {
    Uri? url = await task.prepare();
    if (url == null) {
      return;
    }
    _tasks.add(task);
  }
  DownloadTask? getTask() {
    if (_tasks.isNotEmpty) {
      return _tasks.removeAt(0);
    }
    return null;
  }

  //
  //  threading
  //

  void start() async {
    _running = true;
    await run();
  }

  void stop() {
    _running = false;
  }

  // protected
  Future<void> run() async {
    while (_running) {
      if (await process()) {
        // it's busy now
      } else {
        await idle();
      }
    }
  }

  // protected
  Future idle() async {
    await Future.delayed(const Duration(milliseconds: 256));
  }

  // protected
  Future<bool> process() async {
    //
    //  0. get next task
    //
    DownloadTask? next = getTask();
    if (next == null) {
      // nothing to do now, return false to have a rest.
      return false;
    }
    //
    //  1. prepare the task
    //
    Uri? url;
    try {
      url = await next.prepare();
    } catch (e, st) {
      Log.error('failed to prepare HTTP task: $next, error: $e, $st');
    }
    if (url == null) {
      // this task doesn't need to download
      // return true for next task immediately
      return true;
    }
    //
    //  2. do the job
    //
    Uint8List? data;
    try {
      data = await download(url,
        onReceiveProgress: (count, total) => next.progress(count, total, url!),
      );
    } catch (e, st) {
      Log.error('failed to download: $url, error: $e, $st');
    }
    //
    //  3. callback with downloaded data
    //
    try {
      await next.process(data, url);
    } catch (e, st) {
      Log.error('failed to process: ${data?.length} bytes, $url, error: $e, $st');
    }
    if (data != null && data.isNotEmpty) {
      // check other task with same URL
      List<DownloadTask> all = _tasks.toList();
      Uri? that;
      for (DownloadTask item in all) {
        try {
          if (item is PortableNetworkLoader) {
            that = item.pnf.url;
            if (that != url) {
              continue;
            }
          }
          Log.info('checking task with same URL: $url, $item');
          that = await item.prepare();
          if (that == null) {
            Log.info('remove task: $item');
            _tasks.remove(item);
          } else if (that == url) {
            assert(false, 'should not happen');
            Log.info('process task with same URL: $url, $item');
            await item.process(data, url);
            _tasks.remove(item);
          }
        } catch (e, st) {
          Log.error('failed to handle: ${data.length} bytes, $url, error: $e, $st');
        }
      }
    }
    return true;
  }

  Future<Uint8List?> download(Uri url, {ProgressCallback? onReceiveProgress});

}

class SharedDownloader extends Downloader {
  factory SharedDownloader() => _instance;
  static final SharedDownloader _instance = SharedDownloader._internal();
  SharedDownloader._internal() {
    start();
  }

  @override
  Future<Uint8List?> download(Uri url, {ProgressCallback? onReceiveProgress}) async {
    return await _HTTPHelper.download(url, onReceiveProgress);
  }

}

class _HTTPHelper {

  static String get userAgent {
    // return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
    //     ' AppleWebKit/537.36 (KHTML, like Gecko)'
    //     ' Chrome/118.0.0.0 Safari/537.36';
    GlobalVariable shared = GlobalVariable();
    return shared.terminal.userAgent;
  }

  static Future<Uint8List?> download(Uri url, ProgressCallback? onReceiveProgress) async {
    Response<Uint8List> response;
    try {
      response = await Dio().getUri<Uint8List>(url,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': userAgent,
          },
        ),
      ).onError((error, stackTrace) {
        Log.error('[DIO] failed to download $url: $error');
        throw Exception(error);
      });
    } catch (e, st) {
      Log.error('failed to download $url: error: $e');
      Log.debug('failed to download $url: error: $e, $st');
      return null;
    }
    int? statusCode = response.statusCode;
    if (statusCode != 200) {
      Log.error('failed to download $url, status: $statusCode - ${response.statusMessage}');
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
