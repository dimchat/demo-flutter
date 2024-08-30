import 'package:dim_client/dim_client.dart';

import 'shared.dart';


class SharedFacebook extends ClientFacebook {
  SharedFacebook();

  @override
  CommonArchivist get archivist {
    GlobalVariable shared = GlobalVariable();
    return shared.archivist;
  }

  @override
  Future<Group?> createGroup(ID identifier) async {
    Group? group;
    if (!identifier.isBroadcast) {
      SharedGroupManager man = SharedGroupManager();
      Bulletin? doc = await man.getBulletin(identifier);
      if (doc != null) {
        group = await super.createGroup(identifier);
        group?.dataSource = man;
      }
    }
    return group;
  }

  Future<PortableNetworkFile?> getAvatar(ID user) async {
    Visa? doc = await getVisa(user);
    return doc?.avatar;
  }

}

class SharedArchivist extends ClientArchivist {
  SharedArchivist(super.database);

  @override
  CommonFacebook? get facebook {
    GlobalVariable shared = GlobalVariable();
    return shared.facebook;
  }

  @override
  CommonMessenger? get messenger {
    GlobalVariable shared = GlobalVariable();
    return shared.messenger;
  }

  @override
  Future<bool> checkMeta(ID identifier, Meta? meta) async {
    if (identifier.isBroadcast) {
      // broadcast entity has no meta to query
      return false;
    }
    return await super.checkMeta(identifier, meta);
  }

  @override
  Future<bool> checkDocuments(ID identifier, List<Document> documents) async {
    if (identifier.isBroadcast) {
      // broadcast entity has no document to update
      return false;
    }
    return await super.checkDocuments(identifier, documents);
  }

  @override
  Future<bool> checkMembers(ID group, List<ID> members) async {
    if (group.isBroadcast) {
      // broadcast group has no members to update
      return false;
    }
    return await super.checkMembers(group, members);
  }

  @override
  Future<bool> queryMeta(ID identifier) async {
    var session = messenger?.session;
    if (session is ClientSession && session.isReady) {} else {
      logWarning('querying meta cancel, waiting to connect: $identifier -> $session');
      return false;
    }
    return await super.queryMeta(identifier);
  }

  @override
  Future<bool> queryDocuments(ID identifier, List<Document> documents) async {
    var session = messenger?.session;
    if (session is ClientSession && session.isReady) {} else {
      logWarning('querying documents cancel, waiting to connect: $identifier -> $session');
      return false;
    }
    return await super.queryDocuments(identifier, documents);
  }

  @override
  Future<bool> queryMembers(ID group, List<ID> members) async {
    Session? session = messenger?.session;
    if (session?.identifier == null) {
      logWarning('querying members cancel, waiting to connect: $group');
      return false;
    }
    return await super.queryMembers(group, members);
  }

}
