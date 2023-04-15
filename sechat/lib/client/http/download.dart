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
import 'package:dim_client/dim_client.dart';

import '../filesys/paths.dart';
import 'task.dart';

abstract class DownloadDelegate {

  ///  Callback when download task success
  ///
  /// @param request - download request
  /// @param path    - temporary file path
  void onDownloadSuccess(DownloadRequest request, String path);

  ///  Callback when download task failed
  ///
  /// @param request - download request
  /// @param error   - error info
  void onDownloadFailed(DownloadRequest request, Exception error);

  ///  Callback when download task error
  ///
  /// @param request - download request
  /// @param error   - error info
  void onDownloadError(DownloadRequest request, Error error);

}

///  Download Request
///  ~~~~~~~~~~~~~~~~
///  waiting task
///
///  properties:
///      url      - remote URL
///      path     - temporary file path
///      delegate - callback
class DownloadRequest extends HttpTask {
  DownloadRequest(Uri url, String path, {required DownloadDelegate delegate})
      : _delegateRef = WeakReference(delegate), super(url, path);

  final WeakReference<DownloadDelegate> _delegateRef;

  DownloadDelegate? get delegate => _delegateRef.target;

  @override
  bool operator ==(Object other) {
    if (other is DownloadRequest) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      // compare with url
      other = other.url.toString();
    } else if (other is Uri) {
      other = other.toString();
    }
    return other is String && other == url.toString();
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz url="$url" path="$path" status=$status />';
  }

}

///  Download Task
///  ~~~~~~~~~~~~~
///  running task
///
///  properties:
///      url      - remote URL
///      path     - temporary file path
///      delegate - HTTP client
class DownloadTask extends DownloadRequest {
  DownloadTask(super.url, super.path, {required super.delegate});

  static Future<Error?> _download(Uri url, String filePath) async {
    // TODO: get file data from remote url to local file path
    Log.warning('download $url to $filePath');
    return null;
  }

  void run() async {
    DownloadDelegate? callback = delegate;
    touch();
    String filePath = path!;
    // 1. prepare directory
    String dir = Paths.parent(filePath)!;
    assert(!dir.startsWith('.'), 'download file path error: $filePath');
    if (await Paths.mkdirs(dir)) {} else {
      // local storage error
      Error error = AssertionError('failed to create dir: $dir');
      if (callback != null) {
        callback.onDownloadError(this, error);
      }
      return;
    }
    // 2. start download
    await _download(url, filePath).then((error) {
      if (error == null) {
        // download success
        onSuccess();
        if (callback != null) {
          callback.onDownloadSuccess(this, filePath);
        }
      } else {
        // response error
        onError();
        if (callback != null) {
          callback.onDownloadError(this, error);
        }
      }
      onFinished();
    }).onError((error, stackTrace) {
      // connection error
      onError();
      if (callback != null) {
        callback.onDownloadFailed(this, Exception(error));
      }
      onFinished();
    });
  }

}
