import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../common/dbi/contact.dart';
import '../client/constants.dart';
import '../client/shared.dart';
import '../network/pni_avatar.dart';
import '../widgets/alert.dart';

import 'amanuensis.dart';
import 'chat.dart';

class ContactInfo extends Conversation {
  ContactInfo(super.identifier, {super.unread = 0, super.lastMessage, super.lastTime}) {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kContactsUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      if (contact == identifier) {
        Log.info('contact updated: $contact');
        setNeedsReload();
        await reloadData();
      }
    } else {
      await super.onReceiveNotification(notification);
    }
  }

  PortableNetworkFile? _avatar;

  // null means checking
  bool? _friendFlag;

  bool get isFriend => _friendFlag == true;
  bool get isNotFriend => _friendFlag == false;

  bool get isNewFriend {
    if (isFriend) {
      // already be friend
      return false;
    } else if (isBlocked) {
      // blocked user will not show in stranger list
      return false;
    } else if (identifier.type == EntityType.kStation) {
      // should not add the station as a friend
      return false;
    }
    return true;
  }

  String? get avatar => _avatar?.url?.toString();

  @override
  String get title {
    String nickname = name;
    // check alias in remark
    ContactRemark cr = remark;
    String alias = cr.alias;
    if (alias.isEmpty) {
      return nickname.isEmpty ? Anonymous.getName(identifier) : nickname;
    } else if (nickname.length > 15) {
      nickname = '${nickname.substring(0, 12)}...';
    }
    return '$nickname ($alias)';
  }

  @override
  Widget getImage({double? width, double? height, GestureTapCallback? onTap}) =>
      AvatarFactory().getAvatarView(identifier, width: width, height: height, onTap: onTap);

  @override
  Future<void> loadData() async {
    await super.loadData();
    // check current user
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not found');
    }
    // get avatar
    Visa? visa = await shared.facebook.getVisa(identifier);
    _avatar = visa?.avatar;
    // get friendship
    if (user == null) {
      _friendFlag = null;
    } else {
      List<ID> contacts = await shared.facebook.getContacts(user.identifier);
      _friendFlag = contacts.contains(identifier);
    }
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

  static ContactInfo? fromID(ID identifier) =>
      identifier.isGroup ? null :
      _ContactManager().getContact(identifier);

  static List<ContactInfo> fromList(List<ID> contacts) {
    List<ContactInfo> array = [];
    _ContactManager man = _ContactManager();
    for (ID item in contacts) {
      if (item.isGroup) {
        Log.warning('ignore group conversation: $item');
        continue;
      }
      array.add(man.getContact(item));
    }
    return array;
  }

}

class ContactSorter {

  List<String> sectionNames = [];
  Map<int, List<ContactInfo>> sectionItems = {};

  static ContactSorter build(List<ContactInfo> contacts) {
    ContactSorter sorter = ContactSorter();
    Set<String> set = {};
    Map<String, List<ContactInfo>> map = {};
    for (ContactInfo item in contacts) {
      String name = item.name;
      String prefix = name.isEmpty ? '#' : name.substring(0, 1).toUpperCase();
      // TODO: convert for Pinyin
      Log.debug('[$prefix] contact: $item');
      set.add(prefix);
      List<ContactInfo>? list = map[prefix];
      if (list == null) {
        list = [];
        map[prefix] = list;
      }
      list.add(item);
    }
    // update
    sorter.sectionNames = [];
    sorter.sectionItems = {};
    int index = 0;
    List<String> array = set.toList();
    array.sort();
    for (String prefix in array) {
      sorter.sectionNames.add(prefix);
      sorter.sectionItems[index] = _sortContacts(map[prefix]);
      index += 1;
    }
    return sorter;
  }
}

List<ContactInfo> _sortContacts(List<ContactInfo>? contacts) {
  if (contacts == null) {
    return [];
  }
  contacts.sort((a, b) => a.name.compareTo(b.name));
  return contacts;
}

class _ContactManager {
  factory _ContactManager() => _instance;
  static final _ContactManager _instance = _ContactManager._internal();
  _ContactManager._internal();

  final Map<ID, ContactInfo> _contacts = {};

  ContactInfo getContact(ID identifier) {
    ContactInfo? info = _contacts[identifier];
    if (info == null) {
      info = ContactInfo(identifier);
      info.reloadData();
      _contacts[identifier] = info;
    }
    return info;
  }

}
