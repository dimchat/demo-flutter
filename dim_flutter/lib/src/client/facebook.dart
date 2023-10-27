import 'package:dim_client/dim_client.dart';

import '../channels/manager.dart';
import '../widgets/browser.dart';
import 'group.dart';

class SharedFacebook extends ClientFacebook {
  SharedFacebook(super.adb);

  @override
  Future<Document?> getDocumentByType(ID identifier, [String? type]) async {
    Document? doc = await super.getDocumentByType(identifier, type);
    // compatible for document type
    if (doc == null && type == Document.kVisa) {
      doc = await super.getDocumentByType(identifier, 'profile');
    }
    return doc;
  }

  @override
  Future<Group?> createGroup(ID identifier) async {
    Group? group;
    if (!identifier.isBroadcast) {
      SharedGroupManager man = SharedGroupManager();
      Bulletin? doc = await getBulletin(identifier);
      if (doc != null) {
        group = await super.createGroup(identifier);
        group?.dataSource = man;
      }
    }
    return group;
  }

  Future<List<ID>> getAdministrators(ID group) async {
    assert(group.isGroup, 'ID error: $group');
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      // group not ready
      return [];
    }
    List<ID> admins = await database.getAdministrators(group: group);
    if (admins.isNotEmpty) {
      // got from database
      return admins;
    }
    // var array = doc.getProperty('administrators');
    // if (array is List) {
    //   // got from bulletin document
    //   return ID.convert(array);
    // }
    // administrators not found
    return [];
  }

  Future<Pair<String?, Uri?>> getAvatar(ID user) async {
    Visa? doc = await getVisa(user);
    String? urlString = doc?.avatar?.toString();
    String? path;
    Uri? url = Browser.parseUri(urlString);
    if (url == null) {} else {
      ChannelManager man = ChannelManager();
      path = await man.ftpChannel.downloadAvatar(url);
    }
    return Pair(path, url);
  }

}
