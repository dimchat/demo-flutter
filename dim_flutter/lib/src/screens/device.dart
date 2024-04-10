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
import 'package:lnc/log.dart';
import 'package:stargate/startrek.dart';


/// Castable Device
abstract class ScreenDevice {

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz uuid="$uuid" type="$deviceType" name="$friendlyName" />';
  }

  //
  //  Specs
  //
  String get deviceType;
  String get friendlyName;
  String get uuid;

  //
  //  Device
  //
  Future<bool> alive();
  Future<void> castURL(Uri url);

}


/// Castable Device Scanner
abstract class ScreenDiscoverer {

  /// Scan available screens
  Future<Iterable<ScreenDevice>> discover();

}


/// Castable Device Manager
class ScreenManager extends Runner with Logging {
  factory ScreenManager() => _instance;
  static final ScreenManager _instance = ScreenManager._internal();
  ScreenManager._internal() : super(Runner.intervalSlow) {
    /*await */run();
  }

  final Map<String, ScreenDevice> _allDevices = {};  /// uuid => screen
  final Set<ScreenDevice> _aliveDevices = {};

  final Set<ScreenDiscoverer> _scanners = {};  /// screen scanner
  bool _dirty = false;
  bool _scanning = false;

  void addDiscoverer(ScreenDiscoverer delegate) => _dirty = _scanners.add(delegate);
  void removeDiscoverer(ScreenDiscoverer delegate) => _scanners.remove(delegate);

  bool get scanning => _scanning || _dirty;

  /// Get cached screen devices
  Iterable<ScreenDevice> get devices => _aliveDevices;

  /// Refresh alive screen devices
  Future<Iterable<ScreenDevice>> getDevices(bool forceRefresh) async {
    if (forceRefresh) {
      _dirty = true;
    }
    if (_scanners.isEmpty) {
      assert(false, 'scanner not set yet');
    } else {
      int count = 128;
      while (count > 0) {
        await Runner.sleep(milliseconds: 512);
        if (_scanning) {
          count += 1;
        } else {
          break;
        }
      }
    }
    return _aliveDevices;
  }

  @override
  Future<bool> process() async {
    List<ScreenDiscoverer> discoverers = _scanners.toList();
    if (discoverers.isEmpty) {
      // screen discoverer not set
      return _scanning = false;
    } else if (_dirty) {
      _dirty = false;
    } else {
      // no need to scan now
      return _scanning = false;
    }
    _scanning = true;
    try {
      var candidates = await _scan(discoverers);
      _aliveDevices.clear();
      _aliveDevices.addAll(candidates);
    } catch (e, st) {
      logError('failed to scan screens: $e, $st');
    }
    _scanning = false;
    return true;
  }

  Future<Iterable<ScreenDevice>> _scan(Iterable<ScreenDiscoverer> discoverers) async {
    Iterable<ScreenDevice> screens;
    //
    //  1. discover new devices
    //
    for (ScreenDiscoverer scanner in discoverers) {
      screens = await scanner.discover();
      for (ScreenDevice tv in screens) {
        _allDevices[tv.uuid] = tv;
      }
    }
    //
    //  2. check alive devices
    //
    Set<ScreenDevice> candidates = {};
    screens = _allDevices.values;
    for (ScreenDevice tv in screens) {
      if (await tv.alive()) {
        logInfo('got alive screen device: $tv');
        candidates.add(tv);
      } else {
        logWarning('screen device not alive: $tv');
        _aliveDevices.remove(tv.uuid);
      }
    }
    return candidates;
  }

}
