import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'client/shared.dart';
import 'models/config.dart';
import 'views/chats.dart';
import 'views/customizer.dart';
import 'views/contacts.dart';
import 'views/register.dart';
import 'views/styles.dart';
import 'widgets/permissions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set log level
  Log.level = Log.kDebug;

  bool released = Log.level == Log.kRelease;
  if (released) {
    // This app is designed only to work vertically, so we limit
    // orientations to portrait up and down.
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
    );
  }

  // Check permission to launch the app: Storage
  checkPrimaryPermissions().then((value) {
    if (!value) {
      // not granted for photos/storage, first run?
      Log.warning('not granted for photos/storage, first run?');
      runApp(const _Application(RegisterPage()));
    } else {
      // check current user
      Log.debug('check current user');
      GlobalVariable().facebook.currentUser.then((user) {
        Log.info('current user: $user');
        if (user == null) {
          runApp(const _Application(RegisterPage()));
        } else {
          runApp(const _Application(_MainPage()));
        }
      }).onError((error, stackTrace) {
        Log.error('current user error: $error');
      });
    }
  }).onError((error, stackTrace) {
    Log.error('check permission error: $error');
  });
}

void changeToMainPage(BuildContext context) {
  Navigator.pop(context);
  Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const _MainPage(),
  ));
}

class _Application extends StatelessWidget {
  const _Application(this.home);

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: const CupertinoThemeData(
        barBackgroundColor: Styles.themeBarBackgroundColor,
      ),
      home: home,
    );
  }
}

class _MainPage extends StatelessWidget {
  const _MainPage();

  @override
  Widget build(BuildContext context) {
    // 1. try connect to a neighbor station
    _connect();
    // 2. build main page
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          ChatHistoryPage.barItem(),
          ContactListPage.barItem(),
          SettingsPage.barItem(),
        ],
      ),
      tabBuilder: (context, index) {
        Widget page;
        if (index == 0) {
          page = const ChatHistoryPage();
        } else if (index == 1) {
          page = const ContactListPage();
        } else {
          page = const SettingsPage();
        }
        return CupertinoTabView(
          builder: (context) {
            return page;
          },
        );
      },
    );
  }
}

/// connect to the neighbor station
void _connect() async {
  String host;
  int port;
  Pair<String, int>? station = await _neighbor();
  if (station == null) {
    // TEST:
    host = '192.168.31.152';
    port = 9394;
  } else {
    host = station.first;
    port = station.second;
  }
  GlobalVariable shared = GlobalVariable();
  await shared.terminal.connect(host, port);
}

/// get neighbor station
Future<Pair<String, int>?> _neighbor() async {
  GlobalVariable shared = GlobalVariable();
  SessionDBI database = shared.sdb;
  await _updateStations(database);
  // check service provider
  List<Pair<ID, int>> providers = await database.getProviders();
  if (providers.isEmpty) {
    return null;
  }
  ID pid = providers.first.first;
  List<_StationInfo> stations = await database.getStations(provider: pid);
  // TODO: take the nearest station
  return stations[0].first;
}

Future<bool> _updateStations(SessionDBI database) async {
  // 1. get stations from config
  Config config = Config();
  Map info = await config.info;
  ID? pid = ID.parse(info['ID']);
  List? stations = info['stations'];
  if (pid == null || stations == null || stations.isEmpty) {
    assert(false, 'config error: $info');
    return false;
  }

  // 2. check service provider
  List<Pair<ID, int>> providers = await database.getProviders();
  if (providers.isEmpty) {
    // database empty, add first provider
    if (await database.addProvider(pid, chosen: 1)) {
      Log.warning('first provider added: $pid');
    } else {
      Log.error('failed to add provider: $pid');
      return false;
    }
  } else {
    // check with providers from database
    bool exists = false;
    for (var item in providers) {
      if (item.first == pid) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      if (await database.addProvider(pid, chosen: 0)) {
        Log.warning('provider added: $pid');
      } else {
        Log.error('failed to add provider: $pid');
        return false;
      }
    }
  }

  // 3. check neighbor stations
  List<_StationInfo> currentStations = await database.getStations(provider: pid);
  String host;
  int port;
  for (Map item in stations) {
    host = item['host'];
    port = item['port'];
    if (_contains(Pair(host, port), currentStations)) {
      Log.debug('station exists: $item');
    } else if (await database.addStation(host, port, provider: pid)) {
      Log.warning('station added: $item, $pid');
    } else {
      Log.error('failed to add station: $item');
      return false;
    }
  }

  // OK
  return true;
}

bool _contains(Pair<String, int> srv, List<_StationInfo> stations) {
  for (var item in stations) {
    if (item.first == srv) {
      return true;
    }
  }
  return false;
}

typedef _StationInfo = Triplet<Pair<String, int>, ID, int>;
