import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/contact.dart';
import 'alert.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage(this.info, {super.key});

  final ContactInfo info;

  static void open(BuildContext context, ContactInfo info) {
    showCupertinoDialog(
      context: context,
      builder: (context) => ProfilePage(info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // A ScrollView that creates custom scroll effects using slivers.
      child: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text(info.name),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: _body(context),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32,),
        info.getIcon(256),
        Text(info.identifier.string),
        const SizedBox(height: 64,),
        SizedBox(
          width: 256,
          child: CupertinoButton.filled(
            child: const Text('Send message'),
            onPressed: () => {
              Alert.show(context, 'Coming soon', 'start chat')
            },
          ),
        ),
        const SizedBox(height: 8,),
        SizedBox(
          width: 256,
          child: CupertinoButton(
            color: Colors.red,
            child: const Text('Delete'),
            onPressed: () => {
              Alert.show(context, 'Coming soon', 'delete record')
            },
          ),
        ),
        const SizedBox(height: 64,),
      ],
    );
  }
}


