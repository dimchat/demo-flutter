import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/shared.dart';
import '../common/dbi/contact.dart';
import '../widgets/alert.dart';

import '../widgets/name_label.dart';
import 'chat_contact.dart';
import 'chat_group.dart';
import 'shield.dart';

/// Chat Info
abstract class Conversation implements lnc.Observer {
  Conversation(this.identifier, {this.unread = 0, this.lastMessage, this.lastTime}) {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kRemarkUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? did = userInfo?['ID'];
      assert(did != null, 'notification error: $notification');
      if (did == identifier) {
        Log.info('document updated: $did');
        setNeedsReload();
        await reloadData();
      }
    } else if (name == NotificationNames.kRemarkUpdated) {
      ID? did = userInfo?['contact'];
      assert(did != null, 'notification error: $notification');
      if (did == identifier) {
        Log.info('remark updated: $did');
        setNeedsReload();
        await reloadData();
      }
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? did = userInfo?['blocked'];
      did ??= userInfo?['unblocked'];
      if (did == identifier) {
        Log.info('blocked contact updated: $did');
        setNeedsReload();
        await reloadData();
      } else if (did == null) {
        Log.info('block-list updated');
        setNeedsReload();
        await reloadData();
      }
    } else if (name == NotificationNames.kMuteListUpdated) {
      ID? did = userInfo?['muted'];
      did ??= userInfo?['unmuted'];
      if (did == identifier) {
        Log.info('muted contact updated: $did');
        setNeedsReload();
        await reloadData();
      } else if (did == null) {
        Log.info('mute-list updated');
        setNeedsReload();
        await reloadData();
      }
    }
  }

  final ID identifier;

  bool _loaded = false;

  String? _name;

  // chat box reference
  WeakReference<Widget>? _widget;
  Widget? get widget => _widget?.target;
  set widget(Widget? chatBox) =>
      _widget = chatBox == null ? null : WeakReference(chatBox);

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
  );

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

  void setNeedsReload() => _loaded = false;

  Future<void> reloadData() async {
    if (_loaded) {
    } else {
      await loadData();
      _loaded = true;
    }
  }

  Future<void> loadData() async {
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not found');
    }
    // get name
    _name = await shared.facebook.getName(identifier);
    // get remark
    if (user != null) {
      _remark = await shared.database.getRemark(identifier, user: user.identifier);
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

  static Conversation? fromID(ID identifier) {
    if (identifier.isGroup) {
      return GroupInfo.fromID(identifier);
    }
    return ContactInfo.fromID(identifier);
  }

  static List<Conversation> fromList(List<ID> chats) {
    List<Conversation> array = [];
    Conversation? info;
    for (ID item in chats) {
      info = fromID(item);
      if (info == null) {
        Log.warning('ignore conversation: $item');
        continue;
      }
      array.add(info);
    }
    return array;
  }

}
