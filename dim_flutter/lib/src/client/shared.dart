
import 'package:dim_client/common.dart';
import 'package:dim_client/group.dart';
import 'package:dim_client/client.dart';

import '../models/config.dart';
import 'compat/loader.dart';
import 'cpu/text.dart';

import 'client.dart';
import 'database.dart';
import 'emitter.dart';
import 'messenger.dart';


class GlobalVariable {
  factory GlobalVariable() => _instance;
  static final GlobalVariable _instance = GlobalVariable._internal();
  GlobalVariable._internal() {
    /// Step 1: prepare
    config = createConfig();
    /// Step 2: create database
    database = createDatabase();
    /// Step 3: create facebook
    facebook = createFacebook(database);
    /// Step 4: create client
    terminal = createClient(facebook, database);
    /// Step 5: create emitter
    emitter = createEmitter();
    /// Step 6: set messenger
  }

  late final Config config;
  late final SharedDatabase database;

  late final ClientFacebook facebook;
  SharedMessenger? _messenger;

  late final SharedEmitter emitter;
  late final Client terminal;

  bool? isBackground;

  SharedMessenger? get messenger => _messenger;
  /// Step 6: set messenger
  set messenger(SharedMessenger? transceiver) {
    _messenger = transceiver;
    // set for group manger
    SharedGroupManager man = SharedGroupManager();
    man.messenger = transceiver;
    // set for entity checker
    var checker = facebook.entityChecker;
    if (checker is ClientChecker) {
      checker.messenger = transceiver;
    } else {
      assert(false, 'entity checker error: $checker');
    }
  }

  /// Step 1: prepare
  static Config createConfig() {
    var loader = CompatLibraryLoader();
    loader.run();
    Config config = Config();
    config.load();
    return config;
  }

  /// Step 2: create database
  static SharedDatabase createDatabase() {
    // create db
    var db = SharedDatabase();
    // purge expired contents
    ServiceContentHandler(db).clearExpiredContents();
    return db;
  }

  /// Step 3: create facebook
  static ClientFacebook createFacebook(SharedDatabase db) {
    var facebook = ClientFacebook(db);
    facebook.barrack = CommonArchivist(facebook, db);
    facebook.entityChecker = ClientChecker(facebook, db);
    // set for group manager
    SharedGroupManager man = SharedGroupManager();
    man.facebook = facebook;
    return facebook;
  }

  /// Step 4: create client
  static Client createClient(ClientFacebook facebook, SharedDatabase db) {
    var client = Client(facebook, db);
    client.start();
    return client;
  }

  /// Step 5: create emitter
  static SharedEmitter createEmitter() {
    return SharedEmitter();
  }

}
