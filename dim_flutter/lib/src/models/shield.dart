
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

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
    await messenger.sendContent(command, sender: null, receiver: Station.EVERY, priority: 1);
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
    await messenger.sendContent(command, sender: null, receiver: Station.ANY, priority: 1);
  }

}

abstract class _BaseShield {

  final Map<ID, bool> _map = {};
  List<ID>? _list;
  User? _user;

  void _clear() {
    _list = null;
    // _map.clear();
  }

  Future<bool> _check(ID contact, User current) async {
    // make sure data loaded
    await _get(current);
    // check value
    return _map[contact] ?? false;
  }

  Future<List<ID>> _get(User current) async {
    if (_user != current) {
      _user = current;
      _clear();
    }
    List<ID>? contacts = _list;
    if (contacts == null) {
      _map.clear();
      contacts = await _load(current);
      for (ID item in contacts) {
        _map[item] = true;
      }
      _list = contacts;
    }
    return contacts;
  }

  Future<List<ID>> _load(User current);

  Future<User?> get currentUser async {
    GlobalVariable shared = GlobalVariable();
    User? current = await shared.facebook.currentUser;
    assert(current != null, 'current user not set');
    return current;
  }
}

class _BlockShield extends _BaseShield {

  Future<List<ID>> getBlockList() async {
    User? current = await currentUser;
    if (current == null) {
      return [];
    }
    return await _get(current);
  }

  Future<bool> isBlocked(ID contact, {required ID? group, req}) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    if (group != null/* && !group.isBroadcast*/) {
      return await _check(group, current);
    }
    return await _check(contact, current);
  }

  Future<bool> addBlocked(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // clear to reload
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.addBlocked(contact, user: current.identifier);
  }

  Future<bool> removeBlocked(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // clear to reload
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.removeBlocked(contact, user: current.identifier);
  }

  @override
  Future<List<ID>> _load(User current) async {
    GlobalVariable shared = GlobalVariable();
    return await shared.database.getBlockList(user: current.identifier);
  }

}

class _MuteShield extends _BaseShield {

  Future<List<ID>> getMuteList() async {
    User? current = await currentUser;
    if (current == null) {
      return [];
    }
    return await _get(current);
  }

  Future<bool> isMuted(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    return await _check(contact, current);
  }

  Future<bool> addMuted(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // clear to reload
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.addMuted(contact, user: current.identifier);
  }

  Future<bool> removeMuted(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // clear to reload
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.removeMuted(contact, user: current.identifier);
  }

  @override
  Future<List<ID>> _load(User current) async {
    GlobalVariable shared = GlobalVariable();
    return await shared.database.getMuteList(user: current.identifier);
  }

}
