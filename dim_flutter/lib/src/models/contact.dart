import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../common/dbi/contact.dart';
import '../client/constants.dart';
import '../client/shared.dart';
import '../network/image_view.dart';
import '../widgets/alert.dart';

import 'conversation.dart';
import 'shield.dart';

class ContactInfo implements lnc.Observer {
  ContactInfo(this.identifier) {
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

  final ID identifier;
  String? _name;
  ContactRemark? _remark;

  bool _friend = false;
  bool _blocked = false;
  bool _muted = false;

  int get type => identifier.type;

  bool get isUser  => identifier.isUser;
  bool get isGroup => identifier.isGroup;

  bool get isFriend => _friend;
  bool get isBlocked => _blocked;
  bool get isMuted => _muted;

  String get name {
    String? nickname = _name;
    if (nickname == null) {
      nickname = _name = '';
      reloadData();
    } else {
      nickname = nickname.trim();
    }
    return nickname;
  }

  ContactRemark get remark {
    ContactRemark? cr = _remark;
    if (cr == null) {
      cr = _remark = ContactRemark.empty(identifier);
      reloadData();
    }
    return cr;
  }

  String get title {
    bool flag = false;
    String? nickname = _name;
    if (nickname == null) {
      nickname = _name = '';
      flag = true;
    } else {
      nickname = nickname.trim();
    }
    ContactRemark? cr = _remark;
    if (cr == null) {
      cr = _remark = ContactRemark.empty(identifier);
      flag = true;
    }
    if (flag) {
      reloadData();
    }
    String alias = cr.alias;
    if (alias.isEmpty) {
      return nickname;
    } else if (nickname.length > 15) {
      nickname = '${nickname.substring(0, 12)}...';
    }
    return '$nickname ($alias)';
  }

  Widget getImage({double? width, double? height, GestureTapCallback? onTap}) =>
      ImageViewFactory().fromID(identifier, width: width, height: height, onTap: onTap);

  @override
  String toString() {
    if (isUser) {
      return '<User id="$identifier" type=$type name="$name"'
          ' isFriend=$_friend blocked=$_blocked muted=$_muted />';
    } else {
      return '<Group id="$identifier" type=$type name="$name"'
          ' isFriend=$_friend blocked=$_blocked muted=$_muted />';
    }
  }

  Future<void> reloadData() async {
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not found');
    }
    // get name
    _name = await shared.facebook.getName(identifier);
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
    // get block status
    Shield shield = Shield();
    _blocked = await shield.isBlocked(identifier);
    _muted = await shield.isMuted(identifier);
  }

  void addToUser(User user, {required BuildContext context}) {
    Alert.confirm(context, 'Confirm', 'Do you want to add this friend?',
      okAction: () => _doAdd(context, identifier, user.identifier),
    );
  }
  void add({required BuildContext context}) {
    // check current user
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        Log.error('current user not found, failed to add contact: $identifier');
        Alert.show(context, 'Error', 'Current user not found');
      } else {
        addToUser(user, context: context);
      }
    });
  }

  void delete({required BuildContext context}) {
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
        Alert.confirm(context, 'Confirm', msg,
          okAction: () => _doRemove(context, identifier, user.identifier),
        );
      }
    });
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
      // info.reloadData();
      _contacts[identifier] = info;
    }
    return info;
  }

}

void _doAdd(BuildContext ctx, ID contact, ID user) {
  GlobalVariable shared = GlobalVariable();
  shared.database.addContact(contact, user: user)
      .then((ok) {
    if (ok) {
      // Navigator.pop(context);
    } else {
      Alert.show(ctx, 'Error', 'Failed to add contact');
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
