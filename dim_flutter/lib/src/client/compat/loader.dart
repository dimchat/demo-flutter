
import 'package:dim_client/sdk.dart';
import 'package:dim_client/plugins.dart';
import 'package:dim_client/compat.dart';
import 'package:dim_client/common.dart';

class CompatLoader extends ClientLoader {

  // @override
  // PluginLoader createPluginLoader() => _PluginLoader();

  @override
  void registerCommandFactories() {
    super.registerCommandFactories();

    // Report (online, offline)
    Command.setFactory("broadcast", CommandParser((dict) => BaseReportCommand(dict)));
    Command.setFactory(ReportCommand.ONLINE, CommandParser((dict) => BaseReportCommand(dict)));
    Command.setFactory(ReportCommand.OFFLINE, CommandParser((dict) => BaseReportCommand(dict)));

    // // Storage (contacts, private_key)
    // Command.setFactory(StorageCommand.STORAGE, StorageCommand::new);
    // Command.setFactory(StorageCommand.CONTACTS, StorageCommand::new);
    // Command.setFactory(StorageCommand.PRIVATE_KEY, StorageCommand::new);

    // Search (users)
    Command.setFactory(SearchCommand.SEARCH, CommandParser((dict) => BaseSearchCommand(dict)));
    Command.setFactory(SearchCommand.ONLINE_USERS, CommandParser((dict) => BaseSearchCommand(dict)));

    // Name Card
    Content.setFactory(ContentType.NAME_CARD, ContentParser((dict) => NameCardContent(dict)));

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
