import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';

import '../client/shared.dart';
import '../models/config.dart';
import '../models/contact.dart';
import '../widgets/alert.dart';
import '../widgets/browser.dart';
import 'account.dart';
import 'styles.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static BottomNavigationBarItem barItem() {
    return const BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.gear),
      label: 'Settings',
    );
  }

  @override
  State<StatefulWidget> createState() => _SettingsState();

}

class _SettingsState extends State<SettingsPage> {

  ID? _identifier;
  String? _nickname;
  Widget? _avatar;

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    await shared.facebook.currentUser.then((user) async {
      ID? identifier = user?.identifier;
      if (identifier != null) {
        ContactInfo info = await ContactInfo.fromID(identifier);
        if (mounted) {
          setState(() {
            _identifier = info.identifier;
            _nickname = info.name;
            _avatar = info.getImage(width: 64, height: 64);
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
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

  Widget _myAccount(BuildContext context) {
    return CupertinoListTile(
      padding: const EdgeInsets.all(16),
      leadingSize: 64,
      leading: _avatar,
      title: Text('$_nickname'),
      subtitle: Text('$_identifier'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => AccountPage.open(context),
    );
  }

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
