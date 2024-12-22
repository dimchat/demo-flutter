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

import 'package:dim_client/ok.dart';
import 'package:dim_client/ws.dart';
import 'package:dim_client/sdk.dart';

import '../common/constants.dart';
import '../models/station.dart';
import '../client/shared.dart';

import 'station_speed.dart';

class VelocityMeter {
  VelocityMeter(this.info);

  final NeighborInfo info;

  String? socketAddress;  // '255.255.255.255:65535'

  String get host => info.host;
  int get port => info.port;
  ID? get identifier => info.identifier;
  double? get responseTime => info.responseTime;

  double _startTime = 0;
  double _endTime = 0;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz host="$host", port=$port id="$identifier" rt=$responseTime />';
  }

  static Future<VelocityMeter> ping(NeighborInfo info) async {
    var nc = NotificationCenter();
    VelocityMeter meter = VelocityMeter(info);
    nc.postNotification(NotificationNames.kStationSpeedUpdated, meter, {
      'state': 'start',
      'meter': meter,
    });
    WebSocketConnector? socket = await meter._connect();
    if (socket == null) {
      nc.postNotification(NotificationNames.kStationSpeedUpdated, meter, {
        'state': 'failed',
        'meter': meter,
      });
    } else {
      nc.postNotification(NotificationNames.kStationSpeedUpdated, meter, {
        'state': 'connected',
        'meter': meter,
      });
      double now = Time.currentTimeSeconds;
      double expired = now + 30;
      while (now < expired) {
        if (await meter._run()) {
          // task finished
          break;
        }
        await Future.delayed(const Duration(milliseconds: 128));
        now = Time.currentTimeSeconds;
      }
      nc.postNotification(NotificationNames.kStationSpeedUpdated, meter, {
        'state': 'finished',
        'meter': meter,
      });
      await socket.close();
    }
    String host = meter.host;
    int port = meter.port;
    ID sid = meter.identifier ?? Station.ANY;
    DateTime now = DateTime.now();
    double rt = meter.responseTime ?? -1;
    String? socketAddress = meter.socketAddress;
    Log.info('station test result: $sid ($host:$port) - $rt, $socketAddress');
    // save the record
    GlobalVariable shared = GlobalVariable();
    await shared.database.addSpeed(host, port, identifier: sid,
        time: now, duration: rt, socketAddress: socketAddress);
    return meter;
  }

  Future<WebSocketConnector?> _connect() async {
    StationSpeeder speeder = StationSpeeder();
    Uint8List? data = await speeder.handshakePackage;
    if (data == null) {
      assert(false, 'failed to get message package');
      return null;
    }
    Log.info('connecting to $host:$port ...');
    // _startTime = Time.currentTimeSeconds;
    Uri url = Uri.parse('ws://$host:$port/');
    WebSocketConnector socket = WebSocketConnector(url);
    try {
      bool ok = await socket.connect();
      if (!ok) {
        Log.error('failed to connect url: $url');
        return null;
      }
    } on Exception catch (e) {
      Log.error('failed to connect $host:$port, $e');
      return null;
    }
    // prepare data handler
    socket.listen((msg) {
      if (_startTime > 0 && msg.length > 64) {
        _endTime = Time.currentTimeSeconds;
      }
      Log.info('received ${msg.length} bytes from $host:$port');
      _caches.add(msg);
    });
    // send
    Log.info('connected, sending ${data.length} bytes to $host:$port ...');
    _startTime = Time.currentTimeSeconds;
    int cnt = await socket.write(data);
    Log.info('$cnt byte(s) sent, waiting response from $host:$port ...');
    return socket;
  }

  final List<Uint8List> _caches = [];

  Future<bool> _run() async {
    if (_caches.isEmpty) {
      // no new income data now
      return false;
    }
    Uint8List? pack = _caches.removeAt(0);
    while (pack != null) {
      if (await _process(pack)) {
        // done!
        return true;
      }
      pack = _caches.removeAt(0);
    }
    return false;
  }

  static bool _checkMessageData(Uint8List data) {
    // {"sender":"","receiver":"","time":0,"data":"","signature":""}
    if (data.length < 64) {
      return false;
    }
    return data.first == _jsonStart && data.last == _jsonEnd;
  }
  static final int _jsonStart = '{'.codeUnitAt(0);
  static final int _jsonEnd   = '}'.codeUnitAt(0);

  Future<bool> _process(Uint8List data) async {
    if (!_checkMessageData(data)) {
      Log.warning('ignore pack: $data');
      return false;
    }
    GlobalVariable shared = GlobalVariable();
    ReliableMessage? rMsg = await shared.messenger?.deserializeMessage(data);
    // ReliableMessage? rMsg = await _decodeMsg(data);
    if (rMsg == null) {
      return false;
    }
    ID sender = rMsg.sender;
    if (sender.type != EntityType.STATION) {
      Log.error('sender not a station: $sender');
      return false;
    }
    double? duration = _endTime - _startTime;
    // OK
    info.identifier = sender;
    info.responseTime = duration;
    // fetch socket address
    try {
      socketAddress = await _decryptAddress(rMsg);
    } catch (e, st) {
      Log.error('socket address not found in message from $sender}, error: $e, $st');
    }
    Log.warning('station ($host:$port) $sender responded within $duration seconds via socket: "$socketAddress"');
    return true;
  }

  static Future<String?> _decryptAddress(SecureMessage sMsg) async {
    GlobalVariable shared = GlobalVariable();
    InstantMessage? iMsg = await shared.messenger?.decryptMessage(sMsg);
    assert(iMsg != null, 'failed to decrypt message: ${sMsg.sender} => ${sMsg.receiver}');
    Content? content = iMsg?.content;
    var remote = content?['remote_address'];
    if (remote is List && remote.length == 2) {
      // 255.255.255.255:65535
      return '${remote.first}:${remote.last}';
    }
    return remote?.toString();
  }

}
