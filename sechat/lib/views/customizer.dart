import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';

import '../models/contact.dart';
import 'alert.dart';
import 'browser.dart';
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
                    _me(context),
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

  ContactInfo _currentUser() {
    // TODO: get current user info
    ID me = ID.kFounder;
    return ContactInfo(identifier: me, type: me.type, name: 'me');
  }
  Widget _me(BuildContext context) {
    ContactInfo user = _currentUser();
    return CupertinoListTile(
      padding: const EdgeInsets.all(16),
      leadingSize: 64,
      leading: user.getIcon(64),
      title: Text(user.name),
      subtitle: Text(user.identifier.string),
      trailing: const CupertinoListTileChevron(),
      onTap: () => {
        Alert.show(context, 'Coming soon', 'Edit profile')
      },
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
