import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'client/shared.dart';

import 'models/channels.dart';
import 'views/chats.dart';
import 'views/customizer.dart';
import 'views/contacts.dart';
import 'views/permissions.dart';
import 'views/register.dart';
import 'views/styles.dart';

void main() {
  // Set log level
  Log.level = Log.kDebug;

  WidgetsFlutterBinding.ensureInitialized();
  // This app is designed only to work vertically, so we limit
  // orientations to portrait up and down.
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
  );
  // Check permission to launch the app: Storage
  PermissionHandler.check(PermissionHandler.minimumPermissions).then((value) {
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

void _connect() async {
  ChannelManager manager = ChannelManager();
  SessionChannel channel = manager.sessionChannel;
  int state = await channel.getState();
  Log.warning('session state: $state');
  // TODO: get neighbor
  // String host = '106.52.25.169';
  String host = '192.168.31.152';
  int port = 9394;
  await channel.connect(host, port).then((value) => _login());
  Future.delayed(const Duration(seconds: 5), () async {
    state = await channel.getState();
    Log.warning('session state: $state');
  });
}

Future<bool> _login() async {
  GlobalVariable shared = GlobalVariable();
  User? user = await shared.facebook.currentUser;
  if (user == null) {
    Log.error('current user not found');
    return false;
  } else {
    Log.warning('setting current user for login: $user');
  }
  ChannelManager manager = ChannelManager();
  SessionChannel channel = manager.sessionChannel;
  return await channel.login(user.identifier);
}
