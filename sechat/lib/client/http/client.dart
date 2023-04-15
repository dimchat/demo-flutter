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
import 'dart:math';
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';

import '../../models/external.dart';
import '../filesys/paths.dart';
import 'download.dart';
import 'task.dart';
import 'upload.dart';

abstract class HTTPClient implements UploadDelegate, DownloadDelegate {

  /// cache for uploaded file's URL
  final Map<String, Uri> _cdn = {};  // filename => URL

  /// requests waiting to upload/download
  final List<UploadRequest>     _uploads = [];
  final List<DownloadRequest> _downloads = [];

  UploadTask? _uploadingTask;
  UploadRequest? _uploadingRequest;
  DownloadTask? _downloadingTask;
  DownloadRequest? _downloadingRequest;

  ///  Add an upload task
  ///
  /// @param api      - remote URL
  /// @param secret   - authentication algorithm: hex(md5(data + secret + salt))
  /// @param data     - file data
  /// @param path     - temporary file path
  /// @param name     - form variable
  /// @param sender   - message sender
  /// @param delegate - callback
  /// @return remote URL for downloading when same file already uploaded to CDN
  Future<Uri?> upload({
    required Uri api,
    required Uint8List secret,
    required Uint8List data,
    required String path,
    required String name,
    required ID sender,
    required UploadDelegate delegate}) async {
    // 1. check previous upload
    String filename = Paths.filename(path)!;
    Uri? url = _cdn[filename];  // filename in format: hex(md5(data)) + ext
    Log.debug('CDN: $filename -> $url');
    if (url != null) {
      // already uploaded
      return url;
    }
    // 2. save file data to the local path
    int len = await ExternalStorage.saveBinary(data, path);
    assert(len == data.length, 'failed to save binary: $path');
    // 3. build request
    UploadRequest req = UploadRequest(api, path,
        secret: secret, name: name, sender: sender, delegate: delegate);
    _uploads.add(req);
    return null;
  }

  ///  Add a download task
  ///
  /// @param url      - remote URL
  /// @param path     - temporary file path
  /// @param delegate - callback
  /// @return temporary file path when same file already downloaded from CDN
  Future<String?> download({
    required Uri url,
    required String path,
    required DownloadDelegate delegate}) async {
    // 1. check previous download
    if (await Paths.exists(path)) {
      // already downloaded
      return path;
    }
    // 2. build request
    DownloadRequest req = DownloadRequest(url, path, delegate: delegate);
    _downloads.add(req);
    return null;
  }

  UploadRequest? _nextUploadRequest() =>
      _uploads.isEmpty ? null : _uploads.removeAt(0);

  DownloadRequest? _nextDownloadRequest() =>
      _downloads.isEmpty ? null : _downloads.removeAt(0);

  Future<bool> _driveUpload() async {
    // 1. check running task
    UploadTask? task = _uploadingTask;
    if (task != null) {
      switch (task.status) {
        case HttpTaskStatus.error:
          Log.error('task error: $task');
          break;

        case HttpTaskStatus.running:
        case HttpTaskStatus.success:
          // task is busy now
          return true;

        case HttpTaskStatus.expired:
          Log.error('task expired: $task');
          break;

        case HttpTaskStatus.finished:
          Log.info('task finished: $task');
          break;

        default:
          assert(task.status == HttpTaskStatus.waiting, 'unknown state: $task');
          Log.warning('task status error: $task');
          break;
      }
      // remove task
      _uploadingTask = null;
      _uploadingRequest = null;
    }

    // 2. get next request
    UploadRequest? req = _nextUploadRequest();
    if (req == null) {
      // nothing to upload now
      return false;
    }

    // 3. check previous upload
    String path = req.path!;
    String filename = Paths.filename(path)!;
    Uri? url = _cdn[filename];
    if (url != null) {
      // uploaded previously
      assert(req.status == HttpTaskStatus.waiting, 'request status error: $req');
      req.onSuccess();
      UploadDelegate? callback = req.delegate;
      if (callback != null) {
        callback.onUploadSuccess(req, url);
      }
      req.onFinished();
      return true;
    }

    // hash: md5(data + secret + salt)
    Uint8List data = await ExternalStorage.loadBinary(path);
    Uint8List secret = req.secret!;
    Uint8List salt = _randomData(16);
    Uint8List hash = MD5.digest(_concatData(data, secret, salt));

    // 4. build task
    String urlString = req.url.toString();
    /// "https://sechat.dim.chat/{ID}/upload?md5={MD5}&salt={SALT}"
    Address address = req.sender!.address;
    urlString = urlString.replaceAll('\\{ID\\}', address.string);
    urlString = urlString.replaceAll('\\{MD5\\}', Hex.encode(hash));
    urlString = urlString.replaceAll('\\{SALT\\}', Hex.encode(salt));
    task = UploadTask(Uri.parse(urlString),
        path, name: req.name, filename: filename, data: data, delegate: this);

    // 5. run it
    _uploadingRequest = req;
    _uploadingTask = task;
    task.run();
    return true;
  }

  Future<bool> _driveDownload() async {
    // 1. check running task
    DownloadTask? task = _downloadingTask;
    if (task != null) {
      switch (task.status) {
        case HttpTaskStatus.error:
          Log.error('task error: $task');
          break;

        case HttpTaskStatus.running:
        case HttpTaskStatus.success:
          // task is busy now
          return true;

        case HttpTaskStatus.expired:
          Log.error('task expired: $task');
          break;

        case HttpTaskStatus.finished:
          Log.info('task finished: $task');
          break;

        default:
          assert(task.status == HttpTaskStatus.waiting, 'unknown state: $task');
          Log.warning('task status error: $task');
          break;
      }
      // remove task
      _downloadingTask = null;
      _downloadingRequest = null;
    }

    // 2. get next request
    DownloadRequest? req = _nextDownloadRequest();
    if (req == null) {
      // nothing to download now
      return false;
    }

    // 3. check previous download
    String path = req.path!;
    if (await Paths.exists(path)) {
      // downloaded previously
      assert(req.status == HttpTaskStatus.waiting, 'request status error: $req');
      req.onSuccess();
      DownloadDelegate? callback = req.delegate;
      if (callback != null) {
        callback.onDownloadSuccess(req, path);
      }
      req.onFinished();
      return true;
    }

    // 4. build task
    task = DownloadTask(req.url, path, delegate: this);

    // 5. run it
    _downloadingRequest = req;
    _downloadingTask = task;
    task.run();
    return true;
  }

  Future<bool> process() async {
    try {
      // drive upload tasks as priority
      if (await _driveUpload() || await _driveDownload()) {
        // it's busy
        return true;
      } else {
        await cleanup();
      }
    } catch (e) {
      Log.error('HTTP client process error: $e');
    }
    return false;
  }

  /// Start a background thread
  Future<void> cleanup();

  void start() {
    // TODO:
  }

  //
  //  UploadDelegate
  //

  @override
  Future<void> onUploadError(UploadRequest request, Error error) async {
    assert(request is UploadTask, 'request task error: $request');
    UploadTask task = request as UploadTask;
    UploadRequest? req = _uploadingRequest;
    assert(task == _uploadingTask, 'tasks not match: $task, $_uploadingTask');
    assert(req != null && req.path!.endsWith(task.filename), 'upload error: $task, $req');
    // callback
    UploadDelegate? callback = req?.delegate;
    if (callback != null) {
      await callback.onUploadError(req!, error);
    }
  }

  @override
  Future<void> onUploadFailed(UploadRequest request, Exception error) async {
    assert(request is UploadTask, 'request task error: $request');
    UploadTask task = request as UploadTask;
    UploadRequest? req = _uploadingRequest;
    assert(task == _uploadingTask, 'tasks not match: $task, $_uploadingTask');
    assert(req != null && req.path!.endsWith(task.filename), 'upload error: $task, $req');
    // callback
    UploadDelegate? callback = req?.delegate;
    if (callback != null) {
      await callback.onUploadFailed(req!, error);
    }
  }

  @override
  Future<void> onUploadSuccess(UploadRequest request, Uri url) async {
    assert(request is UploadTask, 'request task error: $request');
    UploadTask task = request as UploadTask;
    UploadRequest? req = _uploadingRequest;
    assert(task == _uploadingTask, 'tasks not match: $task, $_uploadingTask');
    assert(req != null && req.path!.endsWith(task.filename), 'upload error: $task, $req');
    // 1. cache upload result
    _cdn[task.filename] = url;
    // 2. callback
    UploadDelegate? callback = req?.delegate;
    if (callback != null) {
      await callback.onUploadSuccess(req!, url);
    }
  }

  //
  //  DownloadDelegate
  //

  @override
  void onDownloadError(DownloadRequest request, Error error) {
    assert(request is DownloadTask, 'request task error: $request');
    DownloadTask task = request as DownloadTask;
    DownloadRequest? req = _downloadingRequest;
    assert(task == _downloadingTask, 'tasks not match: $task, $_downloadingTask');
    assert(req != null && req.url == task.url, 'download error: $task, $req');
    // callback
    DownloadDelegate? callback = req?.delegate;
    if (callback != null) {
      callback.onDownloadError(req!, error);
    }
  }

  @override
  void onDownloadFailed(DownloadRequest request, Exception error) {
    assert(request is DownloadTask, 'request task error: $request');
    DownloadTask task = request as DownloadTask;
    DownloadRequest? req = _downloadingRequest;
    assert(task == _downloadingTask, 'tasks not match: $task, $_downloadingTask');
    assert(req != null && req.url == task.url, 'download error: $task, $req');
    // callback
    DownloadDelegate? callback = req?.delegate;
    if (callback != null) {
      callback.onDownloadFailed(req!, error);
    }
  }

  @override
  void onDownloadSuccess(DownloadRequest request, String path) {
    assert(request is DownloadTask, 'request task error: $request');
    DownloadTask task = request as DownloadTask;
    DownloadRequest? req = _downloadingRequest;
    assert(task == _downloadingTask, 'tasks not match: $task, $_downloadingTask');
    assert(req != null && req.url == task.url, 'download error: $task, $req');
    // callback
    DownloadDelegate? callback = req?.delegate;
    if (callback != null) {
      callback.onDownloadSuccess(req!, path);
    }
  }

}

Uint8List _concatData(Uint8List data, Uint8List secret, Uint8List salt) {
  BytesBuilder builder = BytesBuilder(copy: false);
  builder.add(data);
  builder.add(secret);
  builder.add(salt);
  return builder.toBytes();
}

Uint8List _randomData(int size) {
  Uint8List data = Uint8List(size);
  Random r = Random();
  for (int i = 0; i < size; ++i) {
    data[i] = r.nextInt(256);
  }
  return data;
}
