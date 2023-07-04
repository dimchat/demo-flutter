import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../common/protocol/block.dart';
import '../common/protocol/mute.dart';
import '../client/shared.dart';


class Shield {
  factory Shield() => _instance;
  static final Shield _instance = Shield._internal();
  Shield._internal();

  ///
  ///   Block
  ///
  final _BlockShield _blockShield = _BlockShield();

  Future<List<ID>> getBlockList() async => await _blockShield.getBlockList();
  Future<bool> addBlocked(ID contact) async => await _blockShield.addBlocked(contact);
  Future<bool> removeBlocked(ID contact) async => await _blockShield.removeBlocked(contact);
  Future<bool> isBlocked(ID contact, {ID? group}) async =>
      await _blockShield.isBlocked(contact, group: group);

  Future<void> broadcastBlockList() async {
    GlobalVariable shared = GlobalVariable();
    var messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set');
      return;
    }
    List<ID> contacts = await getBlockList();
    Log.info('broadcast block-list command: $contacts');
    BlockCommand command = BlockCommand.fromList(contacts);
    // broadcast 'block-list' to all stations,
    // so that the blocked user's message will be stopped at the first station.
    await messenger.sendContent(command, sender: null, receiver: Station.kEvery, priority: 1);
  }

  ///
  ///   Mute
  ///
  final _MuteShield _muteShield = _MuteShield();

  Future<List<ID>> getMuteList() async => await _muteShield.getMuteList();
  Future<bool> addMuted(ID contact) async => await _muteShield.addMuted(contact);
  Future<bool> removeMuted(ID contact) async => await _muteShield.removeMuted(contact);
  Future<bool> isMuted(ID contact) async => await _muteShield.isMuted(contact);

  Future<void> broadcastMuteList() async {
    GlobalVariable shared = GlobalVariable();
    var messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set');
      return;
    }
    List<ID> contacts = await getMuteList();
    Log.info('broadcast mute-list command: $contacts');
    MuteCommand command = MuteCommand.fromList(contacts);
    // send 'mute-list' to current station only,
    // because other stations will know that where this user is roaming to,
    // and only the last roamed station will push notification when the user is offline.
    await messenger.sendContent(command, sender: null, receiver: Station.kAny, priority: 1);
  }

}

class _BlockShield {

  final Map<ID, bool> _blockMap = {};
  List<ID>? _blockList;

  Future<List<ID>> getBlockList() async {
    List<ID>? contacts = _blockList;
    if (contacts == null) {
      _blockMap.clear();
      GlobalVariable shared = GlobalVariable();
      User? currentUser = await shared.facebook.currentUser;
      if (currentUser == null) {
        assert(false, 'current user not set');
      } else {
        contacts = await shared.database.getBlockList(user: currentUser.identifier);
        for (ID item in contacts) {
          _blockMap[item] = true;
        }
        _blockList = contacts;
      }
    }
    return contacts ?? [];
  }

  Future<bool> isBlocked(ID contact, {required ID? group}) async {
    if (_blockList == null) {
      await getBlockList();
    }
    if (group != null/* && !group.isBroadcast*/) {
      return _blockMap[group] ?? false;
    }
    return _blockMap[contact] ?? false;
  }

  Future<bool> addBlocked(ID contact) async {
    GlobalVariable shared = GlobalVariable();
    User? currentUser = await shared.facebook.currentUser;
    if (currentUser == null) {
      assert(false, 'current user not set');
      return false;
    }
    // clear to reload
    _blockList = null;
    _blockMap.clear();
    return await shared.database.addBlocked(contact, user: currentUser.identifier);
  }

  Future<bool> removeBlocked(ID contact) async {
    GlobalVariable shared = GlobalVariable();
    User? currentUser = await shared.facebook.currentUser;
    if (currentUser == null) {
      assert(false, 'current user not set');
      return false;
    }
    // clear to reload
    _blockList = null;
    _blockMap.clear();
    return await shared.database.removeBlocked(contact, user: currentUser.identifier);
  }

}

class _MuteShield {

  final Map<ID, bool> _muteMap = {};
  List<ID>? _muteList;

  Future<List<ID>> getMuteList() async {
    List<ID>? contacts = _muteList;
    if (contacts == null) {
      _muteMap.clear();
      GlobalVariable shared = GlobalVariable();
      User? currentUser = await shared.facebook.currentUser;
      if (currentUser == null) {
        assert(false, 'current user not set');
      } else {
        contacts = await shared.database.getMuteList(user: currentUser.identifier);
        for (ID item in contacts) {
          _muteMap[item] = true;
        }
        _muteList = contacts;
      }
    }
    return contacts ?? [];
  }

  Future<bool> isMuted(ID contact) async {
    if (_muteList == null) {
      await getMuteList();
    }
    return _muteMap[contact] ?? false;
  }

  Future<bool> addMuted(ID contact) async {
    GlobalVariable shared = GlobalVariable();
    User? currentUser = await shared.facebook.currentUser;
    if (currentUser == null) {
      assert(false, 'current user not set');
      return false;
    }
    // clear to reload
    _muteList = null;
    _muteMap.clear();
    return await shared.database.addMuted(contact, user: currentUser.identifier);
  }

  Future<bool> removeMuted(ID contact) async {
    GlobalVariable shared = GlobalVariable();
    User? currentUser = await shared.facebook.currentUser;
    if (currentUser == null) {
      assert(false, 'current user not set');
      return false;
    }
    // clear to reload
    _muteList = null;
    _muteMap.clear();
    return await shared.database.removeMuted(contact, user: currentUser.identifier);
  }

}
