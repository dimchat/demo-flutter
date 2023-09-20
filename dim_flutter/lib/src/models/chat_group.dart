import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/group.dart';
import '../client/shared.dart';
import '../common/dbi/contact.dart';
import '../network/image_view.dart';

import '../widgets/alert.dart';
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

  ContactRemark? _remark;

  String? _temporaryTitle;

  ContactRemark get remark {
    ContactRemark? cr = _remark;
    if (cr == null) {
      // create an empty remark and reload again
      _remark = cr = ContactRemark.empty(identifier);
      reloadData();
    }
    return cr;
  }

  @override
  String get title {
    String name = super.title;
    if (name.isEmpty) {
      name = _temporaryTitle ?? '';
    }
    // check alias in remark
    ContactRemark cr = remark;
    String alias = cr.alias;
    if (alias.isEmpty) {
      return name;
    } else if (name.length > 15) {
      name = '${name.substring(0, 12)}...';
    }
    return '$name ($alias)';
  }

  @override
  Widget getImage({double? width, double? height, GestureTapCallback? onTap}) =>
      ImageViewFactory().fromID(identifier, width: width, height: height, onTap: onTap);

  @override
  Future<void> reloadData() async {
    await super.reloadData();
    // check current user
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not found');
    }
    // get remark
    if (user == null) {
      _remark = ContactRemark.empty(identifier);
    } else {
      var cr = await shared.database.getRemark(identifier, user: user.identifier);
      cr ??= ContactRemark.empty(identifier);
      _remark = cr;
    }
    // check group name
    String name = super.title;
    if (name.isEmpty && _temporaryTitle == null) {
      _temporaryTitle = '';
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

  void setName({required BuildContext context, required String name}) {
    // update memory
    if (name.isEmpty || name == title) {
      return;
    } else {
      title = name;
    }
    // save into document
    _updateGroupName(identifier, name).then((message) {
      if (message != null) {
        Alert.show(context, 'Error', message);
      }
    });
  }
  static Future<String?> _updateGroupName(ID group, String name) async {
    GlobalVariable shared = GlobalVariable();
    // 0. get local user
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return 'Failed to get current user.';
    }
    ID me = user.identifier;
    // 1. check permission
    GroupManager man = GroupManager();
    if (await man.dataSource.isOwner(me, group: group)) {
      Log.info('updating group $group by owner $me');
    } else {
      Log.error('cannot update group name: $group, $name');
      return 'Permission denied';
    }
    // 2. get old document
    Document? bulletin = await man.dataSource.getDocument(group, '*');
    if (bulletin == null) {
      // TODO: create a new bulletin?
      assert(false, 'failed to get group document: $group');
      return 'Failed to get group document';
    }
    // 2.1. get sign key for local user
    SignKey? sKey = await shared.facebook.getPrivateKeyForVisaSignature(me);
    if (sKey == null) {
      assert(false, 'failed to get sign key for user: $user');
      return 'Failed to get sign key';
    }
    // 2.2. update group name and sign it
    bulletin.name = name;
    if (bulletin.sign(sKey) == null) {
      assert(false, 'failed to sign group document: $group');
      return 'Failed to sign group document';
    }
    // 3. save into local storage and broadcast it
    if (await man.dataSource.updateDocument(bulletin)) {
      Log.warning('group document updated: $group');
    } else {
      assert(false, 'failed to update group document: $group');
      return 'Failed to update group document';
    }
    // OK
    return null;
  }

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
        Log.error('current user not found, failed to add contact: $identifier');
        Alert.show(context, 'Error', 'Current user not found');
      } else {
        shared.database.setRemark(cr!, user: user.identifier).then((ok) {
          if (ok) {
            Log.info('set remark: $cr, user: $user');
          } else {
            Log.error('failed to set remark: $cr, user: $user');
            Alert.show(context, 'Error', 'Failed to set remark');
          }
        });
      }
    });
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
