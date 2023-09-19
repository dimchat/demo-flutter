import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../common/dbi/contact.dart';
import '../client/constants.dart';
import '../client/shared.dart';
import '../network/image_view.dart';
import '../widgets/alert.dart';

import 'chat.dart';

class ContactInfo extends Conversation implements lnc.Observer {
  ContactInfo(super.identifier, {super.unread = 0, super.lastMessage, super.lastTime}) {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
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
    } else if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      Log.info('contact updated: $contact');
      if (contact == identifier) {
        await reloadData();
      }
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? contact = userInfo?['blocked'];
      contact ??= userInfo?['unblocked'];
      Log.info('blocked contact updated: $contact');
      if (contact != null) {
        if (contact == identifier) {
          await reloadData();
        }
      } else {
        // block-list updated
        await reloadData();
      }
    } else {
      Log.error('notification error: $notification');
    }
  }

  String? _avatar;
  ContactRemark? _remark;

  bool _friend = false;

  bool get isFriend => _friend;

  bool get isNewFriend {
    if (_friend) {
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

  String? get avatar {
    String? url = _avatar;
    if (url == null) {
      _avatar = '';
      reloadData();
    } else if (url.isEmpty) {
      url = null;
    }
    return url;
  }

  ContactRemark get remark {
    ContactRemark? cr = _remark;
    if (cr == null) {
      cr = _remark = ContactRemark.empty(identifier);
      reloadData();
    }
    return cr;
  }

  @override
  String get title {
    String nickname = super.title;
    ContactRemark? cr = _remark;
    if (cr == null) {
      // create an empty remark and reload again
      _remark = cr = ContactRemark.empty(identifier);
      reloadData();
    }
    // check alias in remark
    String alias = cr.alias;
    if (alias.isEmpty) {
      return nickname;
    } else if (nickname.length > 15) {
      nickname = '${nickname.substring(0, 12)}...';
    }
    return '$nickname ($alias)';
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
    // get avatar
    Document? visa = await shared.facebook.getDocument(identifier, '*');
    if (visa is Visa) {
      _avatar = visa.avatar?.url.toString();
    } else {
      _avatar = '';
    }
    // get remark
    if (user == null) {
      _remark = ContactRemark.empty(identifier);
    } else {
      var cr = await shared.database.getRemark(identifier, user: user.identifier);
      cr ??= ContactRemark.empty(identifier);
      _remark = cr;
    }
    // get friendship
    if (user == null) {
      _friend = false;
    } else {
      List<ID> contacts = await shared.facebook.getContacts(user.identifier);
      _friend = contacts.contains(identifier);
    }
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

  static ContactInfo fromID(ID identifier) =>
      _ContactManager().getContact(identifier);

  static List<ContactInfo> fromList(List<ID> contacts) {
    List<ContactInfo> array = [];
    _ContactManager man = _ContactManager();
    for (ID item in contacts) {
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
      String name = item.title;
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
  contacts.sort((a, b) => a.title.compareTo(b.title));
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
      // info.reloadData();
      _contacts[identifier] = info;
    }
    return info;
  }

}
