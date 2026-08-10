
import 'package:dim_client/compat.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/cpu.dart';
import 'package:dim_client/plugins.dart';

import '../../common/protocol/search.dart';
import '../../models/amanuensis.dart';
import '../../ui/translation.dart';
import '../cpu/translate.dart';
import '../cpu/text.dart';
import '../database.dart';


class CompatLibraryLoader extends LibraryLoader {
  CompatLibraryLoader() : super(extensionLoader: _CompatExtensionLoader());

  AppCustomizedFilter get customizedFilter {
    var filter = sharedMessageExtensions.customizedFilter;
    if (filter is AppCustomizedFilter) {
      return filter;
    }
    filter = AppCustomizedFilter();
    sharedMessageExtensions.customizedFilter = filter;
    return filter;
  }

  void registerCustomizedHandlers(SharedDatabase database) {

    var filter = customizedFilter;

    // Translation
    var trans = TranslateContentHandler();
    filter.setContentHandler(app: Translator.app, mod: Translator.mod, handler: trans);
    filter.setContentHandler(app: Translator.app, mod: 'test', handler: trans);

    // Services
    var service = ServiceContentHandler(database);
    ServiceContentHandler.appModules.forEach((app, modules) {
      for (var mod in modules) {
        filter.setContentHandler(app: app, mod: mod, handler: service);
      }
    });

  }
}

class _CompatExtensionLoader extends ClientExtensionLoader {

  @override
  void registerCommandFactories() {
    super.registerCommandFactories();

    // Report (online, offline)
    setCommandFactory("broadcast", creator: (dict) => BaseReportCommand(dict));
    // setCommandFactory(ReportCommand.ONLINE, creator: (dict) => BaseReportCommand(dict));
    // setCommandFactory(ReportCommand.OFFLINE, creator: (dict) => BaseReportCommand(dict));

    // Search: users
    setCommandFactory(SearchCommand.SEARCH,       creator: (dict) => BaseSearchCommand(dict));
    setCommandFactory(SearchCommand.ONLINE_USERS, creator: (dict) => BaseSearchCommand(dict));

    // // Storage (contacts, private_key)
    // Command.setFactory(StorageCommand.STORAGE, StorageCommand::new);
    // Command.setFactory(StorageCommand.CONTACTS, StorageCommand::new);
    // Command.setFactory(StorageCommand.PRIVATE_KEY, StorageCommand::new);

  }

  @override
  void registerCustomizedHandlers() {
    super.registerCustomizedHandlers();

    var filter = sharedMessageExtensions.customizedFilter;
    // 'chat.dim.messenger:chat_history'
    (filter as AppCustomizedFilter).setContentHandler(
      app: SyncChatContent.APP,
      mod: SyncChatContent.MOD,
      handler: _ChatHistoryHandler(),
    );
  }

}

class _ChatHistoryHandler extends ChatHistoryHandler {

  @override
  Future<bool> saveInstantMessage(InstantMessage iMsg) async {
    Amanuensis clerk = Amanuensis();
    return await clerk.saveInstantMessage(iMsg);
  }

}

// class _PluginLoader extends ClientPluginLoader {
//
//   @override
//   void registerAddressFactory() {
//     /// TODO: register address factory (extends BaseAddressFactory)
//     ///
//     Address.setFactory(CompatibleAddressFactory());
//   }
//
//   @override
//   void registerMetaFactories() {
//     /// TODO: register meta factory (extends GeneralMetaFactory)
//     ///
//     var mkm = CompatibleMetaFactory(Meta.MKM);
//     var btc = CompatibleMetaFactory(Meta.BTC);
//     var eth = CompatibleMetaFactory(Meta.ETH);
//
//     Meta.setFactory('1', mkm);
//     Meta.setFactory('2', btc);
//     Meta.setFactory('4', eth);
//
//     Meta.setFactory('mkm', mkm);
//     Meta.setFactory('btc', btc);
//     Meta.setFactory('eth', eth);
//
//     Meta.setFactory('MKM', mkm);
//     Meta.setFactory('BTC', btc);
//     Meta.setFactory('ETH', eth);
//   }
//
// }
