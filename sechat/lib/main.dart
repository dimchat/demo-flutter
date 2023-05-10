import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:lnc/lnc.dart' show Log;

import 'client/shared.dart';
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
  if (Platform.isIOS) {
    Log.colorful = false;
    Log.showTime = false;
    Log.showCaller = true;
  } else {
    Log.colorful = true;
    Log.showTime = true;
    Log.showCaller = true;
  }

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
  Widget build(BuildContext context) => CupertinoApp(
    theme: const CupertinoThemeData(
      barBackgroundColor: Styles.themeBarBackgroundColor,
    ),
    home: home,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
    ],
  );
}

class _MainPage extends StatelessWidget {
  const _MainPage();

  @override
  Widget build(BuildContext context) => CupertinoTabScaffold(
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
