
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/group.dart';
import 'package:dim_client/client.dart';


class SharedFacebook extends ClientFacebook {
  SharedFacebook(super.database);

  @override
  Future<User?> selectLocalUser(ID receiver) async {
    if (receiver.isBroadcast) {
      List<User> users = await archivist.localUsers;
      if (users.isEmpty) {
        assert(false, 'local users should not be empty');
        return null;
      } else {
        // broadcast message can decrypt by anyone, so just return current user
        logInfo('select first user for broadcast receiver: $receiver -> $users');
        return users.first;
      }
    }
    return await super.selectLocalUser(receiver);
  }

  Future<PortableNetworkFile?> getAvatar(ID user) async {
    Visa? doc = await getVisa(user);
    return doc?.avatar;
  }

}

class SharedArchivist extends CommonArchivist {
  SharedArchivist(super.facebook, super.database);

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

}
