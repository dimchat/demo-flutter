
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/client.dart';

import 'any.dart';
import 'handshake.dart';
import 'search.dart';
import 'text.dart';

class SharedContentProcessorCreator extends ClientContentProcessorCreator {
  SharedContentProcessorCreator(super.facebook, super.messenger);

  @override
  ContentProcessor? createContentProcessor(int msgType) {
    // customizable text
    if (msgType == ContentType.TEXT) {
      return TextContentProcessor(facebook!, messenger!);
    }
    // default
    if (msgType == ContentType.ANY) {
      return AnyContentProcessor(facebook!, messenger!);
    }
    // others
    return super.createContentProcessor(msgType);
  }

  @override
  ContentProcessor? createCommandProcessor(int msgType, String cmd) {
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
