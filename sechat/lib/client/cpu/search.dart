import 'package:dim_client/dim_client.dart';

import '../constants.dart';
import '../protocol/search.dart';

class SearchCommandProcessor extends BaseCommandProcessor {
  SearchCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is SearchCommand, 'search command error: $content');
    SearchCommand command = content as SearchCommand;

    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kSearchUpdated, this, {
      'cmd': command,
    });

    return [];
  }

}
