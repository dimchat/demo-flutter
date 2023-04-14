import 'package:dim_client/dim_client.dart';

import 'client.dart';
import 'database.dart';
import 'emitter.dart';
import 'facebook.dart';
import 'messenger.dart';
import 'protocol/search.dart';

class GlobalVariable {
  factory GlobalVariable() => _instance;
  static final GlobalVariable _instance = GlobalVariable._internal(SharedDatabase());
  GlobalVariable._internal(this.database)
      : adb = database, mdb = database, sdb = database,
        facebook = SharedFacebook(database), emitter = Emitter() {
    _registerPlugins();
    terminal = Client(facebook, database);
  }

  final AccountDBI adb;
  final MessageDBI mdb;
  final SessionDBI sdb;
  final SharedDatabase database;

  final SharedFacebook facebook;

  final Emitter emitter;

  SharedMessenger? messenger;

  late final Client terminal;

}

void _registerPlugins() {

  ClientFacebook.prepare();

  //
  //  Register command parsers
  //

  // Report (online, offline)
  Command.setFactory("broadcast", CommandParser((dict) => ReportCommand(dict)));
  Command.setFactory(ReportCommand.kOnline, CommandParser((dict) => ReportCommand(dict)));
  Command.setFactory(ReportCommand.kOffline, CommandParser((dict) => ReportCommand(dict)));

  // // Storage (contacts, private_key)
  // Command.setFactory(StorageCommand.STORAGE, StorageCommand::new);
  // Command.setFactory(StorageCommand.CONTACTS, StorageCommand::new);
  // Command.setFactory(StorageCommand.PRIVATE_KEY, StorageCommand::new);

  // Search (users)
  Command.setFactory(SearchCommand.kSearch, CommandParser((dict) => SearchCommand(dict)));
  Command.setFactory(SearchCommand.kOnlineUsers, CommandParser((dict) => SearchCommand(dict)));

}
