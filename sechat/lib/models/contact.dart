import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';

import '../client/shared.dart';
import '../widgets/facade.dart';

class ContactInfo {
  ContactInfo({required this.identifier}) : _name = identifier.name;

  final ID identifier;
  String? _name;

  int get type => identifier.type;

  bool get isUser  => identifier.isUser;
  bool get isGroup => identifier.isGroup;

  String get name => _name ?? '';

  Widget getImage({double? width, double? height}) =>
      Facade.fromID(identifier, width: width, height: height);

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
      sorter.sectionItems[index] = map[prefix]!;
      index += 1;
    }
    return sorter;
  }
}

class _ContactManager {
  factory _ContactManager() => _instance;
  static final _ContactManager _instance = _ContactManager._internal();
  _ContactManager._internal();

  final Map<ID, ContactInfo> _contacts = {};

  Future<ContactInfo> getContact(ID identifier) async{
    ContactInfo? info = _contacts[identifier];
    if (info == null) {
      info = ContactInfo(identifier: identifier);
      await info.reloadData();
      _contacts[identifier] = info;
    }
    return info;
  }

}
