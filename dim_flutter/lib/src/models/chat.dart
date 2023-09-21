import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';

import '../client/shared.dart';
import '../widgets/alert.dart';

import 'chat_contact.dart';
import 'chat_group.dart';
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
  set title(String name) => _name = name;

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

  static Conversation fromID(ID identifier) {
    if (identifier.isGroup) {
      return GroupInfo.fromID(identifier);
    }
    return ContactInfo.fromID(identifier);
  }

  static List<Conversation> fromList(List<ID> chats) {
    List<Conversation> array = [];
    for (ID item in chats) {
      array.add(fromID(item));
    }
    return array;
  }

}
