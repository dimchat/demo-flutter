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

import 'weak.dart';

///  Notification observer
abstract class Observer {

  Future<void> onReceiveNotification(Notification notification);
}

///  Notification object with name, sender and extra info
class Notification {
  Notification(this.name, this.sender, this.userInfo);

  final String name;
  final dynamic sender;
  final Map? userInfo;

}

///  Notification center
class NotificationCenter {
  factory NotificationCenter() => _instance;
  static final NotificationCenter _instance = NotificationCenter._internal();
  NotificationCenter._internal();

  BaseCenter center = BaseCenter();

  ///  Add observer with notification name
  ///
  /// @param observer - who will receive notification
  /// @param name - notification name
  void addObserver(Observer observer, String name) {
    center.addObserver(observer, name);
  }

  ///  Remove observer for notification name
  ///
  /// @param observer - who will receive notification
  /// @param name - notification name
  void removeObserver(Observer observer, [String? name]) {
    center.removeObserver(observer, name);
  }

  ///  Post a notification with extra info
  ///
  /// @param name - notification name
  /// @param sender - who post this notification
  /// @param userInfo - extra info
  void postNotification(String name, dynamic sender, [Map? userInfo]) {
    center.postNotification(name, sender, userInfo);
  }

  ///  Post a notification
  ///
  /// @param notification - notification object
  void post(Notification notification) {
    center.post(notification);
  }

}

class BaseCenter {

  // name => WeakSet<Observer>
  final Map<String, Set<Observer>> _observers = {};

  ///  Add observer with notification name
  ///
  /// @param observer - listener
  /// @param name     - notification name
  void addObserver(Observer observer, String name) {
    Set<Observer>? listeners = _observers[name];
    if (listeners == null) {
      listeners = WeakSet();
      listeners.add(observer);
      _observers[name] = listeners;
    } else {
      listeners.add(observer);
    }
  }

  ///  Remove observer from notification center
  ///
  /// @param observer - listener
  /// @param name     - notification name
  void removeObserver(Observer observer, [String? name]) {
    if (name == null) {
      // 1. remove from all observer set
      _observers.forEach((key, listeners) {
        listeners.remove(observer);
      });
      // 2. remove empty set
      _observers.removeWhere((key, listeners) => listeners.isEmpty);
    } else {
      // 3. get listeners by name
      Set<Observer>? listeners = _observers[name];
      if (listeners != null && listeners.remove(observer)) {
        // observer removed
        if (listeners.isEmpty) {
          _observers.remove(name);
        }
      }
    }
  }

  ///  Post notification with name
  ///
  /// @param name     - notification name
  /// @param sender   - notification sender
  /// @param userInfo - extra info
  Future<void> postNotification(String name, dynamic sender, [Map? userInfo]) async {
    await post(Notification(name, sender, userInfo));
  }

  Future<void> post(Notification notification) async {
    Set<Observer>? listeners = _observers[notification.name]?.toSet();
    if (listeners == null) {
      Log.warning('no listeners for notification: ${notification.name}');
      return;
    }
    for (Observer item in listeners) {
      try {
        await item.onReceiveNotification(notification)
            .onError((error, stackTrace) {
              Log.error('observer error: $error');
            });
      } catch (ex) {
        Log.error('notification observer exception: $ex');
      }
    }
  }

}
