import 'package:dim_client/dim_client.dart';

import 'any.dart';
import 'search.dart';
import 'text.dart';

class SharedContentProcessorCreator extends ClientContentProcessorCreator {
  SharedContentProcessorCreator(super.facebook, super.messenger);

  @override
  ContentProcessor? createContentProcessor(int msgType) {
    // customizable text
    if (msgType == ContentType.kText) {
      return TextContentProcessor(facebook!, messenger!);
    }
    // default
    if (msgType == 0) {
      return AnyContentProcessor(facebook!, messenger!);
    }
    // others
    return super.createContentProcessor(msgType);
  }

  @override
  ContentProcessor? createCommandProcessor(int msgType, String cmd) {
    // search (users)
    if (cmd == SearchCommand.kOnlineUsers ||
        cmd == SearchCommand.kSearch) {
      return SearchCommandProcessor(facebook!, messenger!);
    }
    // others
    return super.createCommandProcessor(msgType, cmd);
  }

}
