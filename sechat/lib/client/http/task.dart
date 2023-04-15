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

///  Base Task
abstract class HttpTask {
  HttpTask(this.url, this.path) : _last = 0, _flag = 0;

  static int expires = 300 * 1000;

  final Uri url;      // remote URL
  final String? path;  // temporary file path

  int _last;  // last update time
  int _flag;  // -1 -> error, 1 -> success, 2-> finished

  ///  Update active time
  void touch() {
    _last = DateTime.now().millisecondsSinceEpoch;
  }

  void onError() {
    assert(_flag == 0, 'flag updated before');
    _flag = -1;
  }

  void onSuccess() {
    assert(_flag == 0, 'flag updated before');
    _flag = 1;
  }

  void onFinished() {
    assert(_flag != 0, 'flag error: $_flag');
    if (_flag == 1) {
      _flag = 2;
    }
  }

  HttpTaskStatus get status {
    if (_flag == -1) {
      return HttpTaskStatus.error;
    } else if (_flag == 0) {
      return HttpTaskStatus.waiting;
    } else if (_flag == 2) {
      return HttpTaskStatus.finished;
    }
    assert(_last > 0, 'touch() not called');
    // task started, check for expired
    int now = DateTime.now().millisecondsSinceEpoch;
    int expired = _last + expires;
    if (now > expired) {
      // TODO: send it again?
      return HttpTaskStatus.expired;
    }
    if (_flag == 1) {
      return HttpTaskStatus.success;
    } else {
      return HttpTaskStatus.running;
    }
  }

}

enum HttpTaskStatus {
  error,
  waiting,  // initialized
  running,  // uploading/downloading
  success,  // upload/download completed, calling delegates
  expired,  // long time no response, task failed
  finished  // task finished
}
