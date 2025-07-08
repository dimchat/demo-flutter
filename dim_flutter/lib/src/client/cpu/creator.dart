
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/client.dart';

import 'any.dart';
import 'customized.dart';
import 'handshake.dart';
import 'search.dart';
import 'text.dart';

class SharedContentProcessorCreator extends ClientContentProcessorCreator {
  SharedContentProcessorCreator(super.facebook, super.messenger);

  @override
  ContentProcessor? createContentProcessor(String msgType) {
    switch (msgType) {

      // customizable text
      case ContentType.TEXT:
      case 'text':
        return TextContentProcessor(facebook!, messenger!);

      // application customized
      case ContentType.APPLICATION:
      case ContentType.CUSTOMIZED:
      case 'application':
      case 'customized':
        return AppCustomizedContentProcessor(facebook!, messenger!);

      // default
      case ContentType.ANY:
      case '*':
        return AnyContentProcessor(facebook!, messenger!);

    }
    // others
    return super.createContentProcessor(msgType);
  }

  @override
  ContentProcessor? createCommandProcessor(String msgType, String cmd) {
    // search (users)
    if (cmd == SearchCommand.ONLINE_USERS ||
        cmd == SearchCommand.SEARCH) {
      return SearchCommandProcessor(facebook!, messenger!);
    }
    // handshake
    if (cmd == HandshakeCommand.HANDSHAKE) {
      return ClientHandshakeProcessor(facebook!, messenger!);
    }
    // others
    return super.createCommandProcessor(msgType, cmd);
  }

}
