import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;

import '../constants.dart';
import '../messenger.dart';
import '../protocol/search.dart';
import '../shared.dart';

class SearchCommandProcessor extends BaseCommandProcessor {
  SearchCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is SearchCommand, 'search command error: $content');
    SearchCommand command = content as SearchCommand;

    List<ID>? users = _checkUsers(command);
    Log.info('search result: ${users?.length} record(s) found');

    var nc = lnc.NotificationCenter();
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
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      assert(false, 'should not happen');
      return null;
    }

    List<ID> array = ID.convert(users);
    for (ID item in array) {
      messenger.queryDocument(item).then((value) {
        if (value) {
          Log.warning('querying document: $item');
        }
      });
      if (item.isUser) {
        continue;
      }
      messenger.queryMembers(item).then((value) {
        if (value) {
          Log.warning('querying members: $item');
        }
      });
    }
    return array;
  }

}
