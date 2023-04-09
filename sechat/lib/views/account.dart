import 'package:flutter/cupertino.dart';

class Entity {
  final String identifier;
  final int type;
  final String name;
  Entity({required this.identifier, required this.type, required this.name});

  bool isUser() {
    return type & 1 == 0;
  }
  bool isGroup() {
    return type & 1 == 1;
  }

  Widget getIcon(double? size) {
    if (isGroup()) {
      return Icon(CupertinoIcons.person_2_fill, size: size);
    } else {
      return Icon(CupertinoIcons.profile_circled, size: size);
    }
  }

  //
  //  factories
  //
  static Entity fromJson(Map json) {
    int type = json['type'] ?? 0;
    if (type & 1 == 0) {
      return User(
        identifier: json['identifier']!,
        name: json['name']!,
        type: type,
        avatar: json['avatar'],
      );
    } else {
      return Group(
        identifier: json['identifier']!,
        name: json['name']!,
        type: type,
      );
    }
  }

  static List<Entity> listFromJson(List json) {
    return json.map((item) => Entity.fromJson(item)).toList();
  }
}

class User extends Entity {
  final String? avatar;
  User({required String identifier, required String name, int type = 0, this.avatar}) :
        super(identifier: identifier, type: type, name: name);

  @override
  String toString() {
    return '<User id="$identifier" type=$type name="$name" avatar="$avatar" />';
  }

  @override
  Widget getIcon(double? size) {
    if (avatar != null) {
      // TODO: build avatar
      return Icon(CupertinoIcons.photo, size: size);
    }
    return super.getIcon(size);
  }
}

class Group extends Entity {
  final String? logo;
  Group({required String identifier, required String name, int type = 1, this.logo}) :
        super(identifier: identifier, type: type, name: name);

  @override
  String toString() {
    return '<Group id="$identifier" type=$type name="$name" logo="$logo" />';
  }

  @override
  Widget getIcon(double? size) {
    if (logo != null) {
      // TODO: build group icon
      return Icon(CupertinoIcons.photo, size: size);
    }
    return super.getIcon(size);
  }
}

class ContactSorter {

  List<String> sectionNames = [];
  Map<int, List<Entity>> sectionItems = {};

  static ContactSorter build(List<Entity> contacts) {
    ContactSorter sorter = ContactSorter();
    Set<String> set = {};
    Map<String, List<Entity>> map = {};
    for (Entity item in contacts) {
      String name = item.name;
      String prefix = name.substring(0, 1);
      // TODO: convert for Pinyin
      debugPrint('[$prefix] contact: $item');
      set.add(prefix);
      List<Entity>? list = map[prefix];
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
