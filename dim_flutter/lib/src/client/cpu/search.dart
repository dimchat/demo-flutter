
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/client.dart';

import '../../common/constants.dart';
import '../facebook.dart';
import '../shared.dart';

class SearchCommandProcessor extends BaseCommandProcessor {
  SearchCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is SearchCommand, 'search command error: $content');
    SearchCommand command = content as SearchCommand;

    List<ID>? users = _checkUsers(command);
    Log.info('search result: ${users?.length} record(s) found');

    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kSearchUpdated, this, {
      'cmd': command,
      'users': users,
    });

    return [];
  }

  List<ID>? _checkUsers(SearchCommand command) {

    List? users = command['users'];
    if (users == null) {
      Log.error('users not found in search response');
      return null;
    }

    GlobalVariable shared = GlobalVariable();
    SharedFacebook facebook = shared.facebook;

    List<ID> array = ID.convert(users);
    for (ID item in array) {
      facebook.getDocuments(item);
      if (item.isGroup) {
        facebook.getMembers(item);
      }
    }
    return array;
  }

}
