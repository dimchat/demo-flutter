
import 'package:dim_client/compat.dart';
import 'package:dim_client/common.dart';

import '../../common/protocol/search.dart';


class CompatLibraryLoader extends LibraryLoader {
  CompatLibraryLoader() : super(extensionLoader: _CompatExtensionLoader());
}

class _CompatExtensionLoader extends CommonExtensionLoader {

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
