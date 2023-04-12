import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'client/shared.dart';

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
  PermissionHandler.check(PermissionHandler.minimumPermissions).then((value) {
    if (!value) {
      // not granted for photos/storage, first run?
      Log.warning('not granted for photos/storage, first run?');
      runApp(const TarsierApp(RegisterPage()));
      PermissionHandler.check(PermissionHandler.minimumPermissions);
    } else {
      // check current user
      Log.debug('check current user');
      GlobalVariable().facebook.currentUser.then((user) {
        Log.info('current user: $user');
        if (user == null) {
          runApp(const TarsierApp(RegisterPage()));
        } else {
          runApp(const TarsierApp(MainPage()));
        }
      });
    }
  });
}

class TarsierApp extends StatelessWidget {
  const TarsierApp(this.home, {super.key});

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

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
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
