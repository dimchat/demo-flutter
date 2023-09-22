import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../client/shared.dart';
import '../common/dbi/contact.dart';
import '../widgets/alert.dart';

import '../widgets/name_label.dart';
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

  // null means checking
  bool? _blocked;
  bool? _muted;

  int get type => identifier.type;
  bool get isUser  => identifier.isUser;
  bool get isGroup => identifier.isGroup;

  /// blocked
  bool get isBlocked => _blocked == true;
  bool get isNotBlocked => _blocked == false;

  /// muted
  bool get isMuted => _muted == true;
  bool get isNotMuted => _muted == false;

  /// icon
  Widget getImage({double? width, double? height, GestureTapCallback? onTap});

  NameLabel getNameLabel({
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    double? textScaleFactor,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
    Color? selectionColor,
  }) => NameLabel(this,
    style:              style,
    strutStyle:         strutStyle,
    textAlign:          textAlign,
    textDirection:      textDirection,
    locale:             locale,
    softWrap:           softWrap,
    overflow:           overflow,
    textScaleFactor:    textScaleFactor,
    maxLines:           maxLines,
    semanticsLabel:     semanticsLabel,
    textWidthBasis:     textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor:     selectionColor,
  )..reload();

  /// name
  String get name => _name ?? '';
  set name(String text) => _name = text;

  String get title => name;
  String get subtitle => lastMessage ?? '';
  DateTime? get time => lastTime;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz id="$identifier" type=$type name="$name" muted=$isMuted>\n'
        '\t<unread>$unread</unread>\n'
        '\t<msg>$subtitle</msg>\n'
        '\t<time>$time</time>\n'
        '</$clazz>';
  }

  ContactRemark? _remark;
  late final ContactRemark _emptyRemark = ContactRemark.empty(identifier);

  /// Remark
  ContactRemark get remark => _remark ?? _emptyRemark;

  void setRemark({required BuildContext context, String? alias, String? description}) {
    // update memory
    ContactRemark? cr = _remark;
    if (cr == null) {
      cr = ContactRemark(identifier, alias: alias ?? '', description: description ?? '');
      _remark = cr;
    } else {
      if (alias != null) {
        cr.alias = alias;
      }
      if (description != null) {
        cr.description = description;
      }
    }
    // save into local database
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        Log.error('current user not found, failed to set remark: $cr => $identifier');
        Alert.show(context, 'Error', 'Current user not found');
      } else {
        shared.database.setRemark(cr!, user: user.identifier).then((ok) {
          if (ok) {
            Log.info('set remark: $cr => $identifier, user: $user');
          } else {
            Log.error('failed to set remark: $cr => $identifier, user: $user');
            Alert.show(context, 'Error', 'Failed to set remark');
          }
        });
      }
    });
  }

  Future<void> reloadData() async {
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not found');
    }
    // get name
    Document? doc = await shared.facebook.getDocument(identifier, '*');
    _name = doc?.name;
    // get remark
    if (_remark == null && user != null) {
      var cr = await shared.database.getRemark(identifier, user: user.identifier);
      if (cr != null) {
        _remark = cr;
      }
    }
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
