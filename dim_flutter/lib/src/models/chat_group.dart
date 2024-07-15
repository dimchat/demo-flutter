import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart' as lnc;

import '../client/shared.dart';
import '../common/dbi/contact.dart';
import '../common/constants.dart';
import '../network/group_image.dart';
import '../ui/nav.dart';
import '../widgets/alert.dart';
import '../widgets/title.dart';

import 'amanuensis.dart';
import 'chat.dart';
import 'chat_contact.dart';


class Invitation {
  Invitation({required this.sender, required this.group, required this.member, required this.time});

  final ID sender;
  final ID group;
  final ID member;

  final DateTime? time;
}


class GroupInfo extends Conversation with Logging {
  GroupInfo(super.identifier, {super.unread = 0, super.lastMessage, super.lastMessageTime, super.mentionedSerialNumber = 0}) {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kGroupHistoryUpdated);
    nc.addObserver(this, NotificationNames.kAdministratorsUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kGroupHistoryUpdated) {
      ID? gid = userInfo?['ID'];
      assert(gid != null, 'notification error: $notification');
      if (gid == identifier) {
        logInfo('group history updated: $gid');
        setNeedsReload();
        await reloadData();
      }
    } else  if (name == NotificationNames.kAdministratorsUpdated) {
      ID? gid = userInfo?['ID'];
      assert(gid != null, 'notification error: $notification');
      if (gid == identifier) {
        logInfo('administrators updated: $gid');
        setNeedsReload();
        await reloadData();
      }
    } else  if (name == NotificationNames.kMembersUpdated) {
      ID? gid = userInfo?['ID'];
      assert(gid != null, 'notification error: $notification');
      if (gid == identifier) {
        logInfo('administrators updated: $gid');
        setNeedsReload();
        await reloadData();
      }
    } else {
      await super.onReceiveNotification(notification);
    }
  }

  ID? _current;

  String? _temporaryTitle;

  ID? _owner;
  List<ID>? _admins;
  List<ID>? _members;

  List<Invitation>? _invitations;
  Pair<ResetCommand?, ReliableMessage?>? _reset;

  /// owner
  bool get isOwner {
    ID? me = _current;
    ID? owner = _owner;
    return me != null && owner != null && me == owner;
  }
  bool get isNotOwner {
    ID? me = _current;
    ID? owner = _owner;
    return me != null && owner != null && me != owner;
  }

  /// administrator
  bool get isAdmin {
    ID? me = _current;
    List<ID>? admins = _admins;
    return me != null && admins != null && admins.contains(me);
  }
  bool get isNotAdmin {
    ID? me = _current;
    List<ID>? admins = _admins;
    return me != null && admins != null && !admins.contains(me);
  }

  /// member
  bool get isMember {
    ID? me = _current;
    List<ID>? members = _members;
    return me != null && members != null && members.contains(me);
  }
  bool get isNotMember {
    ID? me = _current;
    List<ID>? members = _members;
    return me != null && members != null && !members.contains(me);
  }

  /// Group Name
  @override
  String get title {
    String text = name;
    if (text.isEmpty) {
      text = _temporaryTitle ?? '';
    }
    // check alias in remark
    ContactRemark cr = remark;
    String alias = cr.alias;
    if (alias.isEmpty) {
      return text.isEmpty ? Anonymous.getName(identifier) : text;
    }
    // trim title
    if (VisualTextUtils.getTextWidth(text) > 25) {
      text = VisualTextUtils.getSubText(text, 22);
      text = '$text...';
    }
    return '$text ($alias)';
  }

  ID? get owner => _owner;
  List<ID> get admins => _admins ?? [];
  List<ID> get members => _members ?? [];

  List<Invitation> get invitations => _invitations ?? [];
  Pair<ResetCommand?, ReliableMessage?> get reset => _reset ?? const Pair(null, null);

  @override
  Widget getImage({double? width, double? height}) =>
      GroupImage(this, width: width, height: height);

  @override
  Future<void> loadData() async {
    await super.loadData();
    // check current user
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    assert(user != null, 'current user not found');
    ID? me = _current = user?.identifier;
    // check membership
    if (me == null) {
      _owner = null;
      _admins = null;
      _members = null;
    } else {
      /// owner
      _owner = await shared.facebook.getOwner(identifier);
      /// admins
      _admins = await shared.facebook.getAdministrators(identifier);
      /// members
      Bulletin? doc = await shared.facebook.getBulletin(identifier);
      if (doc == null) {
        _members = null;
        _temporaryTitle = null;
      } else {
        List<ID> members = _members = await shared.facebook.getMembers(identifier);
        List<ContactInfo> users = [];
        ContactInfo? info;
        for (ID item in members) {
          info = ContactInfo.fromID(item);
          if (info == null) {
            logWarning('failed to get contact: $item');
            continue;
          }
          users.add(info);
        }
        // check group name
        if (name.isEmpty && _temporaryTitle == null) {
          _temporaryTitle = await buildGroupName(members);
        }
        // post notification
        var nc = lnc.NotificationCenter();
        nc.postNotification(NotificationNames.kParticipantsUpdated, this, {
          'ID': identifier,
          'members': members,
        });
      }
    }
    if (_owner == null || _members == null) {
      _invitations = [];
      _reset = const Pair(null, null);
    } else {
      AccountDBI db = shared.database;
      List<Pair<GroupCommand, ReliableMessage>> histories = await db.getGroupHistories(group: identifier);
      GroupCommand content;
      ReliableMessage rMsg;
      List<Invitation> array = [];
      List<ID> members;
      for (var item in histories) {
        content = item.first;
        rMsg = item.second;
        assert(content.group == identifier, 'group ID not match: $identifier, $content');
        if (content is InviteCommand) {
          members = content.members ?? [];
        } else if (content is JoinCommand) {
          members = [rMsg.sender];
        } else {
          logDebug('ignore group command: ${content.cmd}');
          continue;
        }
        logInfo('${rMsg.sender} invites $members');
        for (var user in members) {
          array.add(Invitation(
            sender: rMsg.sender,
            group: identifier,
            member: user,
            time: content.time ?? rMsg.time,
          ));
        }
      }
      _invitations = array;
      _reset = await db.getResetCommandMessage(group: identifier);
    }
  }

  static Future<String> buildGroupName(List<ID> members) async {
    assert(members.isNotEmpty, 'members should not be empty here');
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;
    String text = await facebook.getName(members.first);
    String nickname;
    for (int i = 1; i < members.length; ++i) {
      nickname = await facebook.getName(members[i]);
      if (nickname.isEmpty) {
        continue;
      }
      text += ', $nickname';
      if (text.length > 32) {
        text = '${text.substring(0, 28)} ...';
        break;
      }
    }
    return text;
  }

  void setGroupName({required BuildContext context, required String name}) {
    // update memory
    if (name == this.name) {
      return;
    } else {
      this.name = name;
    }
    // save into document
    _updateGroupName(identifier, name).then((message) {
      if (message != null) {
        Alert.show(context, 'Error', message.tr);
      }
    });
  }
  static Future<String?> _updateGroupName(ID group, String text) async {
    GlobalVariable shared = GlobalVariable();
    // 0. get local user
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return 'Failed to get current user.';
    }
    ID me = user.identifier;
    // 1. check permission
    SharedGroupManager man = SharedGroupManager();
    if (await man.isOwner(me, group: group)) {
      Log.info('updating group $group by owner $me');
    } else {
      Log.error('cannot update group name: $group, $text');
      return 'Permission denied';
    }
    // 2. get old document
    Bulletin? bulletin = await man.getBulletin(group);
    if (bulletin == null) {
      // TODO: create a new bulletin?
      assert(false, 'failed to get group document: $group');
      return 'Failed to get group document';
    } else {
      // clone for modifying
      Document? clone = Document.parse(bulletin.copyMap(false));
      if (clone is Bulletin) {
        bulletin = clone;
      } else {
        assert(false, 'bulletin error: $bulletin, $group');
        return 'Group document error';
      }
    }
    // 2.1. get sign key for local user
    SignKey? sKey = await shared.facebook.getPrivateKeyForVisaSignature(me);
    if (sKey == null) {
      assert(false, 'failed to get sign key for user: $user');
      return 'Failed to get sign key';
    }
    // 2.2. update group name and sign it
    bulletin.name = text.trim();
    Uint8List? sig = bulletin.sign(sKey);
    if (sig == null) {
      assert(false, 'failed to sign group document: $bulletin, $me');
      return 'Failed to sign group document';
    }
    // 3. save into local storage and broadcast it
    if (await shared.facebook.saveDocument(bulletin)) {
      Log.warning('group document saved: $group');
    } else {
      assert(false, 'failed to save group document: $bulletin');
      return 'failed to save group document';
    }
    if (await man.broadcastGroupDocument(bulletin)) {
      Log.warning('group document broadcast: $group');
    } else {
      assert(false, 'failed to broadcast group document: $bulletin');
      return 'Failed to broadcast group document';
    }
    // OK
    return null;
  }

  void quit({required BuildContext context}) {
    // check current user
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        logError('current user not found, failed to add contact: $identifier');
        Alert.show(context, 'Error', 'Current user not found'.tr);
      } else {
        // confirm removing group
        Alert.confirm(context, 'Confirm', 'Sure to remove this group?'.tr,
          okAction: () => _doQuit(context, identifier, user.identifier),
        );
      }
    });
  }
  void _doQuit(BuildContext ctx, ID group, ID user) {
    // 1. quit group
    SharedGroupManager man = SharedGroupManager();
    man.quitGroup(group).then((out) {
      // 2. remove conversation
      Amanuensis clerk = Amanuensis();
      clerk.removeConversation(group);
      // 3. remove from contact list
      GlobalVariable shared = GlobalVariable();
      shared.database.removeContact(group, user: user);
      // OK
      closePage(ctx);
    }).onError((error, stackTrace) {
      Alert.show(ctx, 'Error', '$error');
    });
  }

  static GroupInfo? fromID(ID identifier) =>
      identifier.isUser ? null :
      _ContactManager().getContact(identifier);

  static List<GroupInfo> fromList(List<ID> contacts) {
    List<GroupInfo> array = [];
    _ContactManager man = _ContactManager();
    for (ID item in contacts) {
      if (item.isUser) {
        Log.warning('ignore user conversation: $item');
        continue;
      }
      array.add(man.getContact(item));
    }
    return array;
  }

}

class _ContactManager {
  factory _ContactManager() => _instance;
  static final _ContactManager _instance = _ContactManager._internal();
  _ContactManager._internal();

  final Map<ID, GroupInfo> _contacts = {};

  GroupInfo getContact(ID identifier) {
    GroupInfo? info = _contacts[identifier];
    if (info == null) {
      info = GroupInfo(identifier);
      _contacts[identifier] = info;
      info.reloadData();
    }
    return info;
  }

}
