import 'package:dim_client/dim_client.dart';

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
