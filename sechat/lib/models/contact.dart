import 'dart:io';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';

import '../client/shared.dart';

class ContactInfo {
  ContactInfo(this.identifier) : _name = identifier.name;

  final ID identifier;
  String? _name;
  String? _path;  // image path

  int get type => identifier.type;

  bool get isUser  => identifier.isUser;
  bool get isGroup => identifier.isGroup;

  String get name => _name ?? '';

  Widget getImage({double? width, double? height}) {
    String? path = _path;
    if (path != null) {
      width ??= 32;
      height ??= 32;
      Image img = Image.file(File(path), width: width, height: height, fit: BoxFit.cover);
      Radius radius = Radius.elliptical(width / 8, height / 8);
      return ClipRRect(
        borderRadius: BorderRadius.all(radius),
        child: img,
      );
    } else if (identifier.isUser) {
      return Icon(CupertinoIcons.profile_circled, size: width,);
    } else {
      return Icon(CupertinoIcons.group, size: width,);
    }
  }

  @override
  String toString() {
    if (isUser) {
      return '<User id="$identifier" type=$type name="$name" />';
    } else {
      return '<Group id="$identifier" type=$type name="$name" />';
    }
  }

  Future<void> reloadData() async {
    GlobalVariable shared = GlobalVariable();
    _name = await shared.facebook.getName(identifier);
    Pair<String?, Uri?> pair = await shared.facebook.getAvatar(identifier);
    _path = pair.first;
  }

  static Future<ContactInfo> fromID(ID identifier) async =>
      await _ContactManager().getContact(identifier);

  static Future<List<ContactInfo>> fromList(List<ID> contacts) async {
    List<ContactInfo> array = [];
    _ContactManager man = _ContactManager();
    for (ID item in contacts) {
      array.add(await man.getContact(item));
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

  Future<ContactInfo> getContact(ID identifier) async{
    ContactInfo? info = _contacts[identifier];
    if (info == null) {
      info = ContactInfo(identifier);
      await info.reloadData();
      _contacts[identifier] = info;
    }
    return info;
  }

}
