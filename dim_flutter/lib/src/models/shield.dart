import 'package:dim_client/dim_client.dart';

import '../client/shared.dart';


class Shield {
  factory Shield() => _instance;
  static final Shield _instance = Shield._internal();
  Shield._internal();

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

  Future<bool> isBlocked(ID contact) async {
    if (contact.type == EntityType.kStation) {
      // block all stations
      return true;
    }
    if (_blockList == null) {
      await getBlockList();
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
