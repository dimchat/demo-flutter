/* license: https://mit-license.org
 *
 *  Cast Screen
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'package:castscreen/castscreen.dart';

import 'package:dim_client/ok.dart';

import 'device.dart';


class CastScreenDiscoverer with Logging implements ScreenDiscoverer {
  factory CastScreenDiscoverer() => _instance;
  static final CastScreenDiscoverer _instance = CastScreenDiscoverer._internal();
  CastScreenDiscoverer._internal();

  @override
  Future<Iterable<ScreenDevice>> discover() async {
    logInfo('discovering devices ...');
    List<Device> devices = [];
    int seconds = 2;
    while (devices.isEmpty && seconds < 10) {
      seconds <<= 1;
      logInfo('discover duration: $seconds seconds');
      devices = await CastScreen.discoverDevice(timeout: Duration(seconds: seconds));
    }
    logInfo('discovered devices: $devices');
    return screens(devices);
  }

  static Iterable<ScreenDevice> screens(Iterable<Device> devices) =>
      devices.map<ScreenDevice>((tv) => _CastScreenDevice(tv));
  static ScreenDevice screen(Device tv) => _CastScreenDevice(tv);

}


class _CastScreenDevice extends ScreenDevice with Logging {
  _CastScreenDevice(this._tv);

  final Device _tv;

  @override
  String get deviceType => _tv.spec.deviceType;

  @override
  String get friendlyName => _tv.spec.friendlyName;

  @override
  String get uuid => _tv.spec.uuid;

  @override
  Future<bool> alive() async => await _tv.alive();

  @override
  Future<bool> castURL(Uri url) async {
    bool isAlive = await alive();
    if (isAlive) {
      logInfo('device "$friendlyName" ($deviceType) is alive, try to play URL: $url');
      _tv.setAVTransportURI(SetAVTransportURIInput(url.toString()));
    } else {
      logError('device "$friendlyName" ($deviceType) is not alive, cannot play URL: $url');
    }
    return isAlive;
  }

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz uuid="$uuid" type="$deviceType" name="$friendlyName">\n\t${_tv.client}\n</$clazz>';
  }

}
