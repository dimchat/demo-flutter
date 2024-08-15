import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart' as lnc;

import '../common/constants.dart';
import '../common/dbi/contact.dart';
import '../client/shared.dart';
import '../widgets/alert.dart';

import '../widgets/name_label.dart';
import 'chat_contact.dart';
import 'chat_group.dart';
import 'shield.dart';

/// Chat Info
abstract class Conversation with Logging implements lnc.Observer {
  Conversation(this.identifier, {this.unread = 0, this.lastMessage, this.lastMessageTime, this.mentionedSerialNumber = 0}) {
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
        logInfo('document updated: $did');
        setNeedsReload();
        await reloadData();
      }
    } else if (name == NotificationNames.kRemarkUpdated) {
      ID? did = userInfo?['contact'];
      assert(did != null, 'notification error: $notification');
      if (did == identifier) {
        logInfo('remark updated: $did');
        setNeedsReload();
        await reloadData();
      }
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? did = userInfo?['blocked'];
      did ??= userInfo?['unblocked'];
      if (did == identifier) {
        logInfo('blocked contact updated: $did');
        setNeedsReload();
        await reloadData();
      } else if (did == null) {
        logInfo('block-list updated');
        setNeedsReload();
        await reloadData();
      }
    } else if (name == NotificationNames.kMuteListUpdated) {
      ID? did = userInfo?['muted'];
      did ??= userInfo?['unmuted'];
      if (did == identifier) {
        logInfo('muted contact updated: $did');
        setNeedsReload();
        await reloadData();
      } else if (did == null) {
        logInfo('mute-list updated');
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
  DateTime? lastMessageTime;   // time of last message
  int mentionedSerialNumber;   // sn of the message mentioned me

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
  Widget getImage({double? width, double? height});

  NameLabel getNameLabel({
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    TextScaler? textScaler,
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
    textScaler:         textScaler,
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
  DateTime? get time => lastMessageTime;

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
        logError('current user not found, failed to set remark: $cr => $identifier');
        Alert.show(context, 'Error', 'Current user not found'.tr);
      } else {
        shared.database.setRemark(cr!, user: user.identifier).then((ok) {
          if (ok) {
            logInfo('set remark: $cr => $identifier, user: $user');
          } else {
            logError('failed to set remark: $cr => $identifier, user: $user');
            Alert.show(context, 'Error', 'Failed to set remark'.tr);
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
      logError('current user not found');
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
          'Never receive message from this contact'.tr,
        );
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
          'Receive message from this contact'.tr,
        );
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
          'Never receive notification from this contact'.tr,
        );
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
          'Receive notification from this contact'.tr,
        );
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
