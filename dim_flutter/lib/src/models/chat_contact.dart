import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../client/packer.dart';
import '../common/dbi/contact.dart';
import '../common/constants.dart';
import '../client/shared.dart';
import '../pnf/auto_avatar.dart';
import '../ui/language.dart';
import '../utils/syntax.dart';
import '../widgets/alert.dart';

import 'amanuensis.dart';
import 'chat.dart';

class ContactInfo extends Conversation {
  ContactInfo(super.identifier, {super.unread = 0, super.lastMessage, super.lastMessageTime, super.mentionedSerialNumber = 0}) {
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
        logInfo('contact updated: $contact');
        setNeedsReload();
        await reloadData();
      }
    } else {
      await super.onReceiveNotification(notification);
    }
  }

  Visa? _visa;

  Visa? get visa => _visa;

  PortableNetworkFile? _avatar;

  DateTime? _lastActiveTime;  // time of last login

  // null means checking
  bool? _friendFlag;

  String? _language;
  String? _locale;
  String? _clientInfo;

  String? get language => _language == null ? _locale : '$_language ($_locale)';
  // String? get locale => _locale;
  String? get clientInfo => _clientInfo;

  bool get isFriend => _friendFlag == true;
  bool get isNotFriend => _friendFlag == false;

  bool get isNewFriend {
    if (isFriend) {
      // already be friend
      return false;
    } else if (isBlocked) {
      // blocked user will not show in stranger list
      return false;
    } else if (identifier.type == EntityType.STATION) {
      // should not add the station as a friend
      return false;
    }
    return true;
  }

  String? get avatar => _avatar?.url?.toString();

  DateTime? get lastActiveTime => _lastActiveTime;

  @override
  String get title {
    String nickname = name;
    // check alias in remark
    ContactRemark cr = remark;
    String desc = cr.alias;
    if (desc.isEmpty) {
      desc = _language ?? '';
      if (desc.isEmpty) {
        return nickname.isEmpty ? Anonymous.getName(identifier) : nickname;
      }
    }
    // trim nickname
    if (VisualTextUtils.getTextWidth(nickname) > 25) {
      nickname = VisualTextUtils.getSubText(nickname, 22);
      nickname = '$nickname...';
    }
    return '$nickname ($desc)';
  }

  @override
  Widget getImage({double? width, double? height, BoxFit? fit}) =>
      AvatarFactory().getAvatarView(identifier, width: width, height: height, fit: fit);

  @override
  Future<void> loadData() async {
    await super.loadData();
    // check current user
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      logError('current user not found');
    }
    // get avatar
    Visa? visa = await shared.facebook.getVisa(identifier);
    _visa = visa;
    _avatar = _visa?.avatar;
    // get active time (visa time & login time)
    _lastActiveTime = visa?.time;
    var pair = await shared.database.getLoginCommandMessage(identifier);
    DateTime? loginTime = pair.first?.time;
    if (_lastActiveTime == null) {
      _lastActiveTime = loginTime;
    } else if (DocumentUtils.isBefore(loginTime, _lastActiveTime)) {
      _lastActiveTime = loginTime;
    }
    // get friendship
    if (user == null) {
      _friendFlag = null;
    } else {
      List<ID> contacts = await shared.facebook.getContacts(user.identifier);
      _friendFlag = contacts.contains(identifier);
    }
    // parse language & client info
    _parseLanguage(visa);
    _parseClient(visa);
  }

  String? _getStringProperty(Visa? visa, String section, String key) {
    var info = visa?.getProperty(section);
    if (info is Map) {} else {
      // assert(info == null, 'property error: $section, $info');
      return null;
    }
    var text = info[key];
    if (text is String) {} else {
      return null;
    }
    text = text.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }
  void _parseLanguage(Visa? visa) {
    LanguageItem? item;
    // check 'app.language'
    String? code1 = _getStringProperty(visa, 'app', 'language');
    item = getLanguageItem(code1);
    if (item != null) {
      _language = item.name;
      _locale = code1;
      return;
    }
    // check 'sys.locale'
    String? code2 = _getStringProperty(visa, 'sys', 'locale');
    item = getLanguageItem(code2);
    if (item != null) {
      _language = item.name;
      _locale = code2;
    }
    // not found
    _locale = code1 ?? code2;
  }
  void _parseClient(Visa? visa) {
    String? name;
    String? version;
    String? os;
    String? store;
    // check 'app.id'
    // check 'app.name'
    // check 'app.version'
    // check 'app.store'
    var app = visa?.getProperty('app');
    if (app is Map) {
      name = app['name'];
      name ??= app['id'];
      version = app['version'];
      store = app['store'];
    }
    // check 'sys.os'
    var sys = visa?.getProperty('sys');
    if (sys is Map) {
      os = sys['os'];
      if (os == 'ios') {
        os = 'iOS';
      } else if (os == 'android') {
        os = 'Android';
      } else if (os == 'macos') {
        os = 'MacOS';
      } else if (os == 'windows') {
        os = 'Windows';
      } else if (os == 'linux') {
        os = 'Linux';
      }
    }
    if (name != null) {
      String? platform;
      if (os == null || os.isEmpty) {
        platform = store;
      } else if (store == null || store.isEmpty) {
        platform = os;
      } else {
        platform = '$os; $store';
      }
      if (platform == null || platform.isEmpty) {
        _clientInfo = '$name $version';
      } else {
        _clientInfo = '$name ($platform) $version';
      }
    }
  }

  void add({required BuildContext context}) {
    // check current user
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        logError('current user not found, failed to add contact: $identifier');
        if (context.mounted) {
          Alert.show(context, 'Error', 'Current user not found'.tr);
        }
      } else if (context.mounted) {
        // confirm adding
        Alert.confirm(context, 'Confirm Add', 'Sure to add this friend?'.tr,
          okAction: () => _doAdd(context, identifier, user.identifier),
        );
      }
    });
  }
  void _doAdd(BuildContext ctx, ID contact, ID user) {
    GlobalVariable shared = GlobalVariable();
    shared.database.addContact(contact, user: user).then((ok) {
      if (ok) {
        // closePage(context);
      } else if (ctx.mounted) {
        Alert.show(ctx, 'Error', 'Failed to add contact'.tr);
      }
    });
    var packer = shared.messenger?.packer;
    if (packer is SharedPacker) {
      logInfo('push visa document to new contact: $contact');
      packer.pushVisa(contact);
    }
  }

  void delete({required BuildContext context}) {
    // check current user
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        logError('current user not found, failed to add contact: $identifier');
        if (context.mounted) {
          Alert.show(context, 'Error', 'Current user not found'.tr);
        }
      } else {
        String msg;
        if (identifier.isUser) {
          msg = 'Sure to remove this friend?'.tr;
        } else {
          msg = 'Sure to remove this group?'.tr;
        }
        // confirm removing
        if (context.mounted) {
          Alert.confirm(context, 'Confirm Delete', msg,
            okAction: () => _doRemove(context, identifier, user.identifier),
          );
        }
      }
    });
  }
  void _doRemove(BuildContext ctx, ID contact, ID user) {
    Amanuensis clerk = Amanuensis();
    clerk.removeConversation(contact).onError((error, stackTrace) {
      if (ctx.mounted) {
        Alert.show(ctx, 'Error', 'Failed to remove conversation'.tr);
      }
      return false;
    });
    GlobalVariable shared = GlobalVariable();
    shared.database.removeContact(contact, user: user).then((ok) {
      if (ok) {
        logWarning('contact removed: $contact, user: $user');
      } else if (ctx.mounted) {
        Alert.show(ctx, 'Error', 'Failed to remove contact'.tr);
      }
    });
  }

  static ContactInfo from(ID identifier, {
    required int unread,
    required String? lastMessage,
    required DateTime? lastMessageTime,
    required int mentionedSerialNumber,
  }) {
    ContactInfo info = _ContactManager().getContactInfo(identifier);
    info.unread = unread;
    info.lastMessage = lastMessage;
    info.lastMessageTime = lastMessageTime;
    info.mentionedSerialNumber = mentionedSerialNumber;
    return info;
  }

  static ContactInfo? fromID(ID identifier) {
    if (identifier.isGroup) {
      return null;
    }
    return _ContactManager().getContactInfo(identifier);
  }

  static List<ContactInfo> fromList(List<ID> contacts) {
    List<ContactInfo> array = [];
    _ContactManager man = _ContactManager();
    for (ID item in contacts) {
      if (item.isGroup) {
        Log.warning('ignore group conversation: $item');
        continue;
      }
      array.add(man.getContactInfo(item));
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

  ContactInfo getContactInfo(ID identifier) {
    ContactInfo? info = _contacts[identifier];
    if (info == null) {
      info = ContactInfo(identifier);
      _contacts[identifier] = info;
      info.reloadData();
    }
    return info;
  }

}
