import 'package:dim_client/dim_client.dart';

import 'client.dart';
import 'database.dart';
import 'emitter.dart';
import 'facebook.dart';
import 'group.dart';
import 'messenger.dart';

class GlobalVariable {
  factory GlobalVariable() => _instance;
  static final GlobalVariable _instance = GlobalVariable._internal(SharedDatabase());
  GlobalVariable._internal(this.database)
      : adb = database, mdb = database, sdb = database, emitter = Emitter() {
    _registerPlugins();
    archivist = SharedArchivist(database);
    facebook = SharedFacebook();
    terminal = Client(facebook, database);
  }

  final AccountDBI adb;
  final MessageDBI mdb;
  final SessionDBI sdb;
  final SharedDatabase database;

  late final ClientArchivist archivist;

  final Emitter emitter;

  SharedFacebook? _facebook;
  SharedFacebook get facebook => _facebook!;
  set facebook(SharedFacebook barrack) {
    _facebook = barrack;
    SharedGroupManager man = SharedGroupManager();
    man.facebook = barrack;
  }

  SharedMessenger? _messenger;
  SharedMessenger? get messenger => _messenger;
  set messenger(SharedMessenger? transceiver) {
    assert(transceiver != null, 'messenger should not empty');
    _messenger = transceiver;
    SharedGroupManager man = SharedGroupManager();
    man.messenger = transceiver;
  }

  late final Client terminal;

}

void _registerPlugins() {

  ClientFacebook.prepare();

  //
  //  Register command/content parsers
  //

  // Report (online, offline)
  Command.setFactory("broadcast", CommandParser((dict) => BaseReportCommand(dict)));
  Command.setFactory(ReportCommand.kOnline, CommandParser((dict) => BaseReportCommand(dict)));
  Command.setFactory(ReportCommand.kOffline, CommandParser((dict) => BaseReportCommand(dict)));

  // // Storage (contacts, private_key)
  // Command.setFactory(StorageCommand.STORAGE, StorageCommand::new);
  // Command.setFactory(StorageCommand.CONTACTS, StorageCommand::new);
  // Command.setFactory(StorageCommand.PRIVATE_KEY, StorageCommand::new);

  // Search (users)
  Command.setFactory(SearchCommand.kSearch, CommandParser((dict) => BaseSearchCommand(dict)));
  Command.setFactory(SearchCommand.kOnlineUsers, CommandParser((dict) => BaseSearchCommand(dict)));

  // Name Card
  Content.setFactory(ContentType.kNameCard, ContentParser((dict) => NameCardContent(dict)));

  // Quote
  Content.setFactory(ContentType.kQuote, ContentParser((dict) => BaseQuoteContent(dict)));

}
