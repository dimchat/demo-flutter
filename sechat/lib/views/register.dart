import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'alert.dart';
import 'browser.dart';
import 'channels.dart';
import 'permissions.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      // A ScrollView that creates custom scroll effects using slivers.
      child: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text('Register'),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: _RegisterBody(),
          ),
        ],
      ),
    );
  }
}

class _RegisterBody extends StatelessWidget {
  const _RegisterBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        SizedBox(
          height: 32,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _WelcomeMessage(),
          ],
        ),
        SizedBox(
          height: 64,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RegisterForm(),
          ],
        ),
        SizedBox(
          height: 256,
        ),
      ],
    );
  }
}

class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 320,
      child: Column(
        children: [
          Text('Welcome to the social network you control!'),
          SizedBox(height: 16,),
          Text('Here is a world where you can host your own communication'
              ' and still be part of a huge network.'
              ' DIM network is decentralized, and there is no one server,'
              ' company, or person running it. Anyone can join and run'
              ' their own services on DIM network.'),
          SizedBox(height: 16,),
          Text('All you need to do is just input a nickname to enter'
              ' the wonderful world now.'),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<StatefulWidget> createState() {
    return _RegisterFormState();
  }
}

class _RegisterFormState extends State<_RegisterForm> {

  bool agreed = false;

  String nickname = '';
  String avatarURL = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Name: ',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 20,
              ),
            ),
            SizedBox(
              width: 160,
              child: CupertinoTextField(
                placeholder: 'your nickname',
                padding: const EdgeInsets.only(left: 10, right: 10,),
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.6,
                ),
                onChanged: (value) {
                  setState(() {
                    nickname = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 32,
        ),
        CupertinoButton(
          color: Colors.red,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          onPressed: () {
            _submit(context, nickname: nickname, avatarURL: avatarURL, agreed: agreed);
          },
          child: const Text("Let's rock!"),
        ),
        _privacyPolicy(),
      ],
    );
  }

  Widget _privacyPolicy() {
    return Row(
      children: [
        CupertinoButton(
            child: Container(
              decoration: BoxDecoration(
                color: agreed
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.white,
                border: Border.all(
                  color: CupertinoColors.systemGrey,
                  style: BorderStyle.solid,
                  width: 1,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(5)),
              ),
              child: Icon(CupertinoIcons.check_mark,
                size: 16,
                color: agreed
                    ? CupertinoColors.white
                    : CupertinoColors.systemGrey,
              ),
            ),
            onPressed: () {
              setState(() {
                agreed = !agreed;
              });
            },
        ),
        const Text('Agreed with the'),
        TextButton(
          child: const Text('DIM Privacy Policy'),
          onPressed: () {
            Browser.open(context,
              Config().termsURL,
              'Terms',
            );
          },
        ),
      ],
    );
  }
}

//
//  Generate DIM user
//

void _submit(BuildContext context, {required String nickname, required String avatarURL, required bool agreed}) {
  PermissionHandler.request(PermissionHandler.minimumPermissions).then((value) => {
    if (!value) {
      // storage permission not granted
      Alert.show(context, 'Permission denied',
        'You should grant the permission to continue using this app.',
        callback: () => PermissionHandler.openAppSettings(),
      )
    } else {
      // check current user
      ChannelManager.instance.facebookChannel.getCurrentUser().then((value) => {
        debugPrint('current user: $value'),
        if (FacebookChannel.isID(value['identifier'])) {
          // current user already exists
          runApp(const TarsierApp(MainPage()))
        } else {
          // current user not exists, create new one
          if (nickname.isEmpty) {
            Alert.show(context, 'Input Name', 'Please input your nickname.')
          } else if (!agreed) {
            Alert.show(context, 'Privacy Policy', 'Please read and agree the privacy policy.')
          } else {
            _generateAccount(context, nickname, avatarURL)
          }
        }
      })
    }
  });
}

void _generateAccount(BuildContext context, String name, String avatar) {
  ChannelManager.instance.registerChannel.createUser(name, avatar).then((result) => {
    if (FacebookChannel.isID(result)) {
      _openMain(context)
    } else {
      Alert.show(context, 'Error', result)
    }
  });
}

void _openMain(BuildContext context) {
  Navigator.pop(context);
  Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const MainPage(),
  ));
}
