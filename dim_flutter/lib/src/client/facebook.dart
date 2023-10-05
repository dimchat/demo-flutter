import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../channels/manager.dart';
import '../widgets/browser.dart';
import 'group.dart';

class SharedFacebook extends ClientFacebook {
  SharedFacebook(super.adb);

  @override
  Future<Group?> createGroup(ID identifier) async {
    Group? group;
    GroupManager man = GroupManager();
    Document? bulletin = await man.dataSource.getDocument(identifier, '*');
    if (bulletin != null) {
      group = await super.createGroup(identifier);
      if (group != null) {
        group.dataSource = man.dataSource;
      }
    }
    return group;
  }

  Future<Pair<String?, Uri?>> getAvatar(ID user) async {
    String? urlString;
    Document? doc = await getDocument(user, '*');
    if (doc != null) {
      if (doc is Visa) {
        urlString = doc.avatar?.toString();
      } else {
        var avatar = PortableNetworkFile.parse(doc.getProperty('avatar'));
        urlString = avatar?.toString();
      }
    }
    String? path;
    Uri? url = Browser.parseUri(urlString);
    if (url == null) {} else {
      ChannelManager man = ChannelManager();
      path = await man.ftpChannel.downloadAvatar(url);
    }
    return Pair(path, url);
  }

  @override
  Future<bool> saveDocument(Document doc) async {
    ID identifier = doc.identifier;
    if (!doc.isValid) {
      Meta? meta = await getMeta(identifier);
      if (meta == null) {
        Log.error('meta not found: $identifier');
        return false;
      } else if (doc.verify(meta.publicKey)) {
        Log.debug('document verified: $identifier');
      } else {
        Log.error('failed to verify document: $identifier');
        return false;
      }
    }
    bool ok = await database.saveDocument(doc);
    if (ok && doc is Bulletin) {
      ID group = doc.identifier;
      assert(group.isGroup, 'group ID error: $group');
      var array = doc.getProperty('administrators');
      if (array is List) {
        List<ID> admins = ID.convert(array);
        ok = await saveAdministrators(admins, group);
      }
    }
    return ok;
  }

  Future<bool> saveMembers(List<ID> members, ID group) async =>
      await database.saveMembers(members, group: group);

  Future<bool> saveAssistants(List<ID> bots, ID group) async =>
      await database.saveAssistants(bots, group: group);

  Future<bool> saveAdministrators(List<ID> admins, ID group) async =>
      await database.saveAdministrators(admins, group: group);

  Future<List<ID>> getAdministrators(ID group) async {
    List<ID> members = await database.getAdministrators(group: group);
    if (members.isEmpty) {
      Document? doc = await getDocument(group, '*');
      if (doc != null) {
        Object? administrators = doc.getProperty('administrators');
        if (administrators is List) {
          members = ID.convert(administrators);
        }
      }
    }
    return members;
  }

}
