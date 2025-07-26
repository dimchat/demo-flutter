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

import 'package:dim_client/client.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../client/cpu/handshake.dart';
import '../client/messenger.dart';
import '../client/shared.dart';
import '../models/station.dart';

import 'velocity.dart';

class StationSpeeder {
  factory StationSpeeder() => _instance;
  static final StationSpeeder _instance = StationSpeeder._internal();
  StationSpeeder._internal();

  Future<void> testAll() async {
    // clear expired records
    GlobalVariable shared = GlobalVariable();
    await shared.database.removeExpiredSpeed(null);
    // test all stations
    int sections = _dataSource.getSectionCount();
    int items;
    ID pid;
    NeighborInfo info;
    for (int sec = 0; sec < sections; ++sec) {
      pid = _dataSource.getSection(sec);
      items = _dataSource.getItemCount(sec);
      // check all stations of this provider
      List<Future<VelocityMeter>> futures = [];
      for (int idx = 0; idx < items; ++idx) {
        info = _dataSource.getItem(sec, idx);
        futures.add(VelocityMeter.ping(info));
      }
      // report speeds after all stations tested
      Future.wait(futures).then((meters) {
        shared.messenger?.reportSpeeds(meters, pid);
      });
    }
  }

  ///
  ///   DataSource for Station
  ///

  late final _StationDataSource _dataSource = _StationDataSource();

  Future<void> reload() async => await _dataSource.reload();

  int getSectionCount() => _dataSource.getSectionCount();

  /// provider ID
  ID getSection(int sec) => _dataSource.getSection(sec);

  int getItemCount(int sec) => _dataSource.getItemCount(sec);

  NeighborInfo getItem(int sec, int idx) => _dataSource.getItem(sec, idx);

  ///
  ///   Package for Handshake
  ///

  Future<Uint8List?> get handshakePackage async {
    ReliableMessage? rMsg = await _rMsg;
    if (rMsg == null) {
      return null;
    }
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    assert(messenger != null, 'messenger not ready');
    return await messenger?.serializeMessage(rMsg);
  }

  Future<ReliableMessage?> get _rMsg async {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      // assert(false, 'messenger not ready');
      return null;
    }
    InstantMessage? iMsg = await _iMsg;
    if (iMsg == null) {
      assert(false, 'failed to build handshake message');
      return null;
    }
    // encrypt message
    SecureMessage? sMsg = await messenger.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: $iMsg');
      return null;
    }
    // sign message
    ReliableMessage? rMsg = await messenger.signMessage(sMsg);
    assert(rMsg != null, 'failed to sign message: $rMsg');
    return rMsg;
  }

  Future<InstantMessage?> get _iMsg async {
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;
    // get current user
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'current user not found');
      return null;
    }
    ID uid = user.identifier;
    ID sid = Station.ANY;
    // check current user's meta & visa document
    Meta? meta = await facebook.getMeta(uid);
    Visa? visa = await facebook.getVisa(uid);
    if (meta == null) {
      assert(false, 'meta should not empty here');
      return null;
    } else if (visa == null) {
      assert(false, 'visa should not empty here');
    }
    // create message envelope and handshake command
    Envelope env = Envelope.create(sender: uid, receiver: sid);
    Content content = ClientHandshakeProcessor.createTestSpeedCommand();
    content.group = Station.EVERY;
    // create instant message with meta & visa
    InstantMessage iMsg = InstantMessage.create(env, content);
    iMsg.setMap('meta', meta);
    iMsg.setMap('visa', visa);
    return iMsg;
  }

}

class _StationDataSource {

  List<ID> _sections = [];
  final Map<ID, List<NeighborInfo>> _items = {};

  Future<void> reload() async {
    GlobalVariable shared = GlobalVariable();
    SessionDBI database = shared.database;
    var records = await database.allProviders();
    List<ID> providers = _sortProviders(records);
    for (ID pid in providers) {
      var stations = await database.allStations(provider: pid);
      _items[pid] = NeighborInfo.sortStations(await NeighborInfo.fromList(stations));
    }
    _sections = providers;
  }

  int getSectionCount() => _sections.length;

  /// provider ID
  ID getSection(int sec) {
    return _sections[sec];
  }

  int getItemCount(int sec) {
    ID pid = _sections[sec];
    return _items[pid]?.length ?? 0;
  }

  NeighborInfo getItem(int sec, int idx) {
    ID pid = _sections[sec];
    return _items[pid]![idx];
  }
}

List<ID> _sortProviders(List<ProviderInfo> records) {
  // 1. sort records
  records.sort((a, b) {
    if (a.identifier.isBroadcast) {
      if (b.identifier.isBroadcast) {} else {
        return -1;
      }
    } else if (b.identifier.isBroadcast) {
      return 1;
    }
    // sort with chosen order
    return b.chosen - a.chosen;
  });
  List<ID> providers = [];
  for (var item in records) {
    providers.add(item.identifier);
  }
  // 2. set GSP to the front
  int pos = providers.indexOf(ProviderInfo.GSP);
  if (pos < 0) {
    // gsp not exists, insert to the front
    providers.insert(0, ProviderInfo.GSP);
  } else if (pos > 0) {
    // move to the front
    providers.removeAt(pos);
    providers.insert(0, ProviderInfo.GSP);
  }
  return providers;
}
