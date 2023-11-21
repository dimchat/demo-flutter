import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../widgets/browse_html.dart';

import 'shared.dart';
import 'group.dart';

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

  Future<Pair<String?, Uri?>> getAvatar(ID user) async {
    Visa? doc = await getVisa(user);
    String? urlString = doc?.avatar?.toString();
    String? path;
    Uri? url = HtmlUri.parseUri(urlString);
    if (url == null) {} else {
      ChannelManager man = ChannelManager();
      path = await man.ftpChannel.downloadAvatar(url);
    }
    return Pair(path, url);
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
  Future<bool> queryMeta(ID identifier) async {
    Session? session = messenger?.session;
    if (session?.identifier == null) {
      Log.warning('querying meta cancel, waiting to connect: $identifier');
      return false;
    }
    return await super.queryMeta(identifier);
  }

  @override
  Future<bool> queryDocuments(ID identifier, List<Document> documents) async {
    Session? session = messenger?.session;
    if (session?.identifier == null) {
      Log.warning('querying documents cancel, waiting to connect: $identifier');
      return false;
    }
    return await super.queryDocuments(identifier, documents);
  }

  @override
  Future<bool> queryMembers(ID identifier, List<ID> members) async {
    Session? session = messenger?.session;
    if (session?.identifier == null) {
      Log.warning('querying members cancel, waiting to connect: $identifier');
      return false;
    }
    return await super.queryMembers(identifier, members);
  }

}
