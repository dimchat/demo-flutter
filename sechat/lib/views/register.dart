import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../client/shared.dart';
import '../main.dart';
import '../models/config.dart';
import '../widgets/alert.dart';
import '../widgets/browser.dart';
import '../widgets/permissions.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // request permission and check current user,
    // if found, change to main page
    _checkCurrentUser(context, () {
      Log.debug('current user not found');
    });
    // build page
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
  State<StatefulWidget> createState() => _RegisterFormState();
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
                onChanged: (value) => setState(() {
                  nickname = value;
                }),
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
            _submit(context, name: nickname, avatar: avatarURL, agreed: agreed);
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
            onPressed: () => setState(() {
              agreed = !agreed;
            }),
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

void _submit(BuildContext context, {required String name, required String avatar, required bool agreed}) {
  _checkCurrentUser(context, () {
    if (name.isEmpty) {
      Alert.show(context, 'Input Name', 'Please input your nickname.');
    } else if (!agreed) {
      Alert.show(context, 'Privacy Policy', 'Please read and agree the privacy policy.');
    } else {
      GlobalVariable shared = GlobalVariable();
      Register register = Register(shared.database);
      register.createUser(name: name, avatar: avatar).then((identifier) {
        shared.database.addUser(identifier).then((value) {
          changeToMainPage(context);
        }).onError((error, stackTrace) {
          Log.error('add user error: $error');
        });
      }).onError((error, stackTrace) {
        Alert.show(context, 'Error', '$error');
      });
    }
  });
}

void _checkCurrentUser(BuildContext context, void Function() onNotFound) {
  Log.debug('checking permissions');
  _requestPermission(context, (context) {
    GlobalVariable().facebook.currentUser.then((user) {
      if (user == null) {
        onNotFound();
      } else {
        changeToMainPage(context);
      }
    }).onError((error, stackTrace) {
      Log.error('current user error: $error');
    });
  });
}

void _requestPermission(BuildContext context, void Function(BuildContext context) onGranted) {
  PermissionHandler.request(PermissionHandler.primaryPermissions).then((value) {
    if (!value) {
      // storage permission not granted
      Alert.show(context, 'Permission denied',
        'You should grant the permission to continue using this app.',
        callback: () => PermissionHandler.openAppSettings(),
      );
    } else {
      Log.info('permission granted');
      onGranted(context);
    }
  }).onError((error, stackTrace) {
    Log.error('request permission error: $error');
  });
}
