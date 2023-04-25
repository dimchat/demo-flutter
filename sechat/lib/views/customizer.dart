import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/shared.dart';
import '../models/config.dart';
import '../models/contact.dart';
import '../widgets/alert.dart';
import '../widgets/browser.dart';
import 'account.dart';
import 'styles.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static BottomNavigationBarItem barItem() {
    return const BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.gear),
      label: 'Settings',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Styles.backgroundColor,
      // A ScrollView that creates custom scroll effects using slivers.
      child: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          const CupertinoSliverNavigationBar(
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text('Settings'),
            border: Styles.navigationBarBorder,
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: Column(
              // mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoListSection(
                  topMargin: 0,
                  additionalDividerMargin: 32,
                  children: [
                    _myAccount(context),
                  ],
                ),
                CupertinoListSection(
                  topMargin: 0,
                  additionalDividerMargin: 32,
                  children: [
                    _setting(context),
                  ],
                ),
                CupertinoListSection(
                  topMargin: 0,
                  additionalDividerMargin: 32,
                  children: [
                    _term(context),
                    _about(context),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _myAccount(BuildContext context) => _MyAccountSection();

  Widget _setting(BuildContext context) {
    return CupertinoListTile(
      padding: const EdgeInsets.all(16),
      leading: const Icon(CupertinoIcons.settings),
      title: const Text('Setting'),
      additionalInfo: const Text('stations'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => {
        Alert.show(context, 'Coming soon', 'Setting stations')
      },
    );
  }

  Widget _term(BuildContext context) {
    Config config = Config();
    return CupertinoListTile(
      padding: const EdgeInsets.all(16),
      leading: const Icon(CupertinoIcons.doc_text),
      title: const Text('Terms'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => Browser.open(context,
        config.termsURL,
        'Terms',
      ),
    );
  }

  Widget _about(BuildContext context) {
    Config config = Config();
    return CupertinoListTile(
      padding: const EdgeInsets.all(16),
      leading: const Icon(CupertinoIcons.info),
      title: const Text('About'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => Browser.open(context,
        config.aboutURL,
        'About',
      ),
    );
  }
}

class _MyAccountSection extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _MyAccountState();

}

class _MyAccountState extends State<_MyAccountSection> implements lnc.Observer {
  _MyAccountState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  ContactInfo? _info;

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    assert(name == NotificationNames.kDocumentUpdated, 'notification error: $notification');
    ID? identifier = info?['ID'];
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (identifier == null) {
      Log.error('notification error: $notification');
    } else if (identifier == user?.identifier) {
      _reload();
    }
  }

  void _reload() {
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) async {
      if (user == null) {
        Log.error('failed to get current user');
        return;
      }
      ContactInfo? info = _info;
      info ??= ContactInfo(user.identifier);
      await info.reloadData();
      if (mounted) {
        setState(() {
          _info = info;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoListTile(
    padding: const EdgeInsets.all(16),
    leadingSize: 64,
    leading: _info?.getImage(width: 64, height: 64),
    title: Text('${_info?.name}'),
    subtitle: Text('${_info?.identifier}'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => AccountPage.open(context),
  );

}
