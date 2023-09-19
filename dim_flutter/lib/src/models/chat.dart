import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' show Log;

import '../client/shared.dart';
import '../widgets/alert.dart';

import 'amanuensis.dart';
import 'contact.dart';
import 'shield.dart';

/// Chat Info
abstract class Conversation {
  Conversation(this.identifier, {this.unread = 0, this.lastMessage, this.lastTime});

  final ID identifier;

  String? _name;

  int unread;           // count of unread messages

  String? lastMessage;  // description of last message
  DateTime? lastTime;   // time of last message

  bool _blocked = false;
  bool _muted = false;

  int get type => identifier.type;
  bool get isUser  => identifier.isUser;
  bool get isGroup => identifier.isGroup;

  bool get isBlocked => _blocked;
  bool get isMuted => _muted;

  Widget getImage({double? width, double? height, GestureTapCallback? onTap});

  String get title => _name?.trim() ?? '';
  String get subtitle => lastMessage?.trim() ?? '';
  DateTime? get time => lastTime;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz id="$identifier" type=$type name="$title" muted=$isMuted>\n'
        '\t<unread>$unread</unread>\n'
        '\t<msg>$subtitle</msg>\n'
        '\t<time>$time</time>\n'
        '</$clazz>';
  }

  Future<void> reloadData() async {
    // get name
    GlobalVariable shared = GlobalVariable();
    _name = await shared.facebook.getName(identifier);
    // get blocked & muted status
    Shield shield = Shield();
    _blocked = await shield.isBlocked(identifier);
    _muted = await shield.isMuted(identifier);
  }

  void block({required BuildContext context}) {
    _blocked = true;
    // update database and broadcast
    Shield shield = Shield();
    shield.addBlocked(identifier).then((ok) {
      if (ok) {
        shield.broadcastBlockList();
        Alert.show(context, 'Blocked',
            'You will never receive message from this contact again.');
      }
    });
  }
  void unblock({required BuildContext context}) {
    _blocked = false;
    // update database and broadcast
    Shield shield = Shield();
    shield.removeBlocked(identifier).then((ok) {
      if (ok) {
        shield.broadcastBlockList();
        Alert.show(context, 'Unblocked',
            'You can receive message from this contact now.');
      }
    });
  }

  void mute({required BuildContext context}) {
    _muted = true;
    // update database and broadcast
    Shield shield = Shield();
    shield.addMuted(identifier).then((ok) {
      if (ok) {
        shield.broadcastMuteList();
        Alert.show(context, 'Muted',
            'You will never receive notification from this contact again.');
      }
    });
  }
  void unmute({required BuildContext context}) {
    _muted = false;
    // update database and broadcast
    Shield shield = Shield();
    shield.removeMuted(identifier).then((ok) {
      if (ok) {
        shield.broadcastMuteList();
        Alert.show(context, 'Unmuted',
            'You can receive notification from this contact now.');
      }
    });
  }

  void add({required BuildContext context}) {
    // check current user
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        Log.error('current user not found, failed to add contact: $identifier');
        Alert.show(context, 'Error', 'Current user not found');
      } else {
        // confirm adding
        Alert.confirm(context, 'Confirm', 'Do you want to add this friend?',
          okAction: () => _doAdd(context, identifier, user.identifier),
        );
      }
    });
  }
  void _doAdd(BuildContext ctx, ID contact, ID user) {
    GlobalVariable shared = GlobalVariable();
    shared.database.addContact(contact, user: user).then((ok) {
      if (ok) {
        // Navigator.pop(context);
      } else {
        Alert.show(ctx, 'Error', 'Failed to add contact');
      }
    });
  }

  void delete({required BuildContext context}) {
    // check current user
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        Log.error('current user not found, failed to add contact: $identifier');
        Alert.show(context, 'Error', 'Current user not found');
      } else {
        String msg;
        if (identifier.isUser) {
          msg = 'Are you sure to remove this friend?\n'
              'This action will clear chat history too.';
        } else {
          msg = 'Are you sure to remove this group?\n'
              'This action will clear chat history too.';
        }
        // confirm removing
        Alert.confirm(context, 'Confirm', msg,
          okAction: () => _doRemove(context, identifier, user.identifier),
        );
      }
    });
  }
  void _doRemove(BuildContext ctx, ID contact, ID user) {
    Amanuensis clerk = Amanuensis();
    clerk.removeConversation(contact).onError((error, stackTrace) {
      Alert.show(ctx, 'Error', 'Failed to remove conversation');
      return false;
    });
    GlobalVariable shared = GlobalVariable();
    shared.database.removeContact(contact, user: user).then((ok) {
      if (ok) {
        Log.warning('contact removed: $contact, user: $user');
      } else {
        Alert.show(ctx, 'Error', 'Failed to remove contact');
      }
    });
  }

  static Conversation fromID(ID identifier) => ContactInfo.fromID(identifier);

  static List<Conversation> fromList(List<ID> chats) {
    List<Conversation> array = [];
    for (ID item in chats) {
      array.add(fromID(item));
    }
    return array;
  }

}