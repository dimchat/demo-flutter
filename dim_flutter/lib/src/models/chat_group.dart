import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/shared.dart';
import '../network/image_view.dart';

import 'chat.dart';

class GroupInfo extends Conversation implements lnc.Observer {
  GroupInfo(super.identifier, {super.unread = 0, super.lastMessage, super.lastTime}) {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
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
        await reloadData();
      }
    } else {
      Log.error('notification error: $notification');
    }
  }

  String? _temporaryTitle;

  @override
  String get title {
    String name = super.title;
    if (name.isNotEmpty) {
      return name;
    }
    reloadData();
    return _temporaryTitle ?? '';
  }

  @override
  Widget getImage({double? width, double? height, GestureTapCallback? onTap}) =>
      ImageViewFactory().fromID(identifier, width: width, height: height, onTap: onTap);

  @override
  Future<void> reloadData() async {
    await super.reloadData();
    // check group name
    String name = super.title;
    if (name.isEmpty && _temporaryTitle == null) {
      _temporaryTitle = '';
      GlobalVariable shared = GlobalVariable();
      Group? group = await shared.facebook.getGroup(identifier);
      if (group != null) {
        List<ID> members = await group.members;
        _temporaryTitle = await buildGroupName(members);
      }
    }
  }

  static Future<String> buildGroupName(List<ID> members) async {
    assert(members.isNotEmpty, 'members should not be empty here');
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;
    String name = await facebook.getName(members.first);
    String nickname;
    for (int i = 1; i < members.length; ++i) {
      nickname = await facebook.getName(members[i]);
      if (nickname.isEmpty) {
        continue;
      }
      name += ', $nickname';
      if (name.length > 32) {
        name = '${name.substring(0, 28)} ...';
        break;
      }
    }
    return name;
  }

  static GroupInfo fromID(ID identifier) =>
      _ContactManager().getContact(identifier);

  static List<GroupInfo> fromList(List<ID> contacts) {
    List<GroupInfo> array = [];
    _ContactManager man = _ContactManager();
    for (ID item in contacts) {
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
      // info.reloadData();
      _contacts[identifier] = info;
    }
    return info;
  }

}
