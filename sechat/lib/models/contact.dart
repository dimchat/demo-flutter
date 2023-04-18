import 'dart:io';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';

import '../client/shared.dart';

class ContactInfo {
  ContactInfo({required this.identifier, required this.type,
    required this.name, this.image});

  final ID identifier;
  final int type;
  final String name;
  final String? image;

  bool get isUser  => EntityType.isUser(type);
  bool get isGroup => EntityType.isGroup(type);

  @override
  String toString() {
    if (isUser) {
      return '<User id="$identifier" type=$type name="$name" avatar="$image" />';
    } else {
      return '<Group id="$identifier" type=$type name="$name" />';
    }
  }

  Widget getIcon(double? size) {
    String? url = image;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('file://')) {
        return Image.file(File(url), width: size, height: size);
      // } else {
      //   return Image.network(url, width: size, height: size);
      }
    }
    if (isGroup) {
      return Icon(CupertinoIcons.person_2_fill, size: size);
    } else {
      return Icon(CupertinoIcons.profile_circled, size: size);
    }
  }

  static Future<ContactInfo> from(ID identifier) async {
    GlobalVariable shared = GlobalVariable();
    String name = await shared.facebook.getName(identifier);
    int type = identifier.type;
    String? image;
    if (EntityType.isUser(type)) {
      Document? doc = await shared.facebook.getDocument(identifier, '*');
      if (doc != null) {
        image = doc.getProperty('avatar');
      }
    }
    return ContactInfo(identifier: identifier, type: type, name: name, image: image);
  }

  static Future<List<ContactInfo>> fromList(List<ID> contacts) async {
    List<ContactInfo> array = [];
    for (ID item in contacts) {
      array.add(await from(item));
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
      String prefix = name.substring(0, 1);
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
    for (String prefix in set) {
      sorter.sectionNames.add(prefix);
      sorter.sectionItems[index] = map[prefix]!;
      index += 1;
    }
    return sorter;
  }
}
