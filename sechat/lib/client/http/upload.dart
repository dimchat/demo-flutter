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
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';

import 'task.dart';

abstract class UploadDelegate {

  ///  Callback when upload task success
  ///
  /// @param request - upload task
  /// @param url     - download URL from server response
  Future<void> onUploadSuccess(UploadRequest request, Uri url);

  ///  Callback when upload task failed
  ///
  /// @param request - upload task
  /// @param error   - error info
  Future<void> onUploadFailed(UploadRequest request, Exception error);

  ///  Callback when upload task error
  ///
  /// @param request - upload task
  /// @param error   - error info
  Future<void> onUploadError(UploadRequest request, Error error);

}

///  Upload Request
///  ~~~~~~~~~~~~~~
///  waiting task
///
///  properties:
///      url      - upload API
///      path     - temporary file path
///      secret   - authentication key
///      name     - form var name ('avatar' or 'file')
///      sender   - message sender
///      delegate - callback
class UploadRequest extends HttpTask {
  UploadRequest(super.url, super.path,
      {this.secret, required this.name, this.sender, required UploadDelegate delegate})
      : _delegateRef = WeakReference(delegate);

  /// authentication algorithm: hex(md5(data + secret + salt))
  final Uint8List? secret;  // upload key
  final String name;       // form var
  final ID? sender;         // message sender

  final WeakReference<UploadDelegate> _delegateRef;

  UploadDelegate? get delegate => _delegateRef.target;

  @override
  bool operator ==(Object other) {
    if (other is UploadRequest) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      // compare with path
      String? otherPath = other.path;
      if (otherPath == null) {
        return other.url == url;
      }
      other = otherPath;
    }
    return other is String && other == path;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz api="$url" sender="$sender" name="$name" path="$path" status=$status />';
  }

}

///  Upload Task
///  ~~~~~~~~~~~
///  running task
///
///  properties:
///      url      - remote URL
///      path     -
///      secret   -
///      name     - form var name ('avatar' or 'file')
///      filename - form file name
///      data     - form file data
///      sender   -
///      delegate - HTTP client
class UploadTask extends UploadRequest {
  UploadTask(super.url, super.path,
      {required super.name, required super.delegate,
        required this.filename, required this.data});

  final String filename;  // file name
  final Uint8List data;   // file data

  static Future<String?> _post(Uri url, String name, String filename, Uint8List data) async {
    // TODO: post data with filename to remote url
    Log.warning('upload $filename to $url');
    return null;
  }

  static Uri? _fetch(String json) {
    // TODO: fetch URL from json response
    Log.warning('fetch download URL from response: $json');
    return null;
  }

  void run() async {
    UploadDelegate? callback = delegate;
    touch();
    // 1. send to server
    await _post(url, name, filename, data).then((response) {
      // 2. get URL from server response
      Uri? url = response == null ? null : _fetch(response);
      if (url == null) {
        // response error
        onError();
        if (callback != null) {
          callback.onUploadError(this, AssertionError('response error: $response'));
        }
      } else {
        // 3. upload success
        onSuccess();
        if (callback != null) {
          callback.onUploadSuccess(this, url);
        }
      }
      onFinished();
    }).onError((error, stackTrace) {
      // connection error
      onError();
      if (callback != null) {
        callback.onUploadFailed(this, Exception(error));
      }
      onFinished();
    });
  }

}
