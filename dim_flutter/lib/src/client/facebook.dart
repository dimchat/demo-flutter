import 'package:dim_client/dim_client.dart';

import '../channels/manager.dart';
import '../widgets/browser.dart';
import 'group.dart';

class SharedFacebook extends ClientFacebook {
  SharedFacebook(super.adb);

  @override
  Future<Group?> createGroup(ID identifier) async {
    Group? group;
    if (!identifier.isBroadcast) {
      SharedGroupManager man = SharedGroupManager();
      Document? bulletin = await man.getDocument(identifier, '*');
      if (bulletin != null) {
        group = await super.createGroup(identifier);
        group?.dataSource = man;
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

}
