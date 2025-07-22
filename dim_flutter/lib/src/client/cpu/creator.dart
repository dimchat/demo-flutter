
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/cpu.dart';

import '../../common/protocol/search.dart';
import '../../ui/translation.dart';
import '../shared.dart';

import 'any.dart';
import 'handshake.dart';
import 'search.dart';
import 'translate.dart';
import 'text.dart';

class SharedContentProcessorCreator extends ClientContentProcessorCreator {
  SharedContentProcessorCreator(super.facebook, super.messenger);

  @override
  AppCustomizedProcessor createCustomizedContentProcessor(Facebook facebook, Messenger messenger) {
    var cpu = super.createCustomizedContentProcessor(facebook, messenger);

    // Translation
    var trans = TranslateContentHandler();
    cpu.setHandler(app: Translator.app, mod: Translator.mod, handler: trans);
    cpu.setHandler(app: Translator.app, mod: 'test', handler: trans);

    // Services
    GlobalVariable shared = GlobalVariable();
    var service = ServiceContentHandler(shared.database);
    ServiceContentHandler.appModules.forEach((app, modules) {
      for (var mod in modules) {
        cpu.setHandler(app: app, mod: mod, handler: service);
      }
    });

    return cpu;
  }

  @override
  ContentProcessor? createContentProcessor(String msgType) {
    switch (msgType) {

      // customizable text
      case ContentType.TEXT:
      case 'text':
        return TextContentProcessor(facebook!, messenger!);

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
