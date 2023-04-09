import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'account.dart';
import 'alert.dart';
import 'channels.dart';
import 'profile.dart';
import 'search.dart';
import 'styles.dart';
import 'tableview.dart';

class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  static BottomNavigationBarItem barItem() {
    return const BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.group),
      label: 'Contacts',
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _ContactListState();
  }
}

class _ContactListState extends State<ContactListPage> {
  _ContactListState() {
    dataSource = _ContactDataSource();
  }

  late final _ContactDataSource dataSource;

  void reloadData() {
    FacebookChannel channel = ChannelManager.instance.facebookChannel;
    channel.getContacts().then((json) => {
      if (json != null) {
        setState(() {
          dataSource.refresh(Entity.listFromJson(json));
        })
      }
    });
  }

  @override
  void initState() {
    super.initState();
    reloadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.backgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Styles.navigationBarBackground,
        border: Styles.navigationBarBorder,
        middle: const Text('Contacts'),
        trailing: SearchPage.searchButton(context),
      ),
      body: SectionListView.builder(
        adapter: _ContactListAdapter(dataSource: dataSource),
      ),
    );
  }
}

class _ContactListAdapter with SectionAdapterMixin {

  final _ContactDataSource dataSource;

  _ContactListAdapter({required this.dataSource});

  @override
  int numberOfSections() {
    // includes fixed section
    return dataSource.getSectionCount() + 1;
  }

  @override
  bool shouldExistSectionHeader(int section) {
    if (section == 0) {
      // fixed section
      return false;
    }
    return true;
  }

  @override
  bool shouldSectionHeaderStick(int section) {
    return true;
  }

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    if (section == 0) {
      // fixed section
      return const Text('...');
    }
    String title = dataSource.getSection(section - 1);
    return Container(
      color: Styles.sectionHeaderBackground,
      padding: Styles.sectionHeaderPadding,
      child: Text(title,
        style: Styles.sectionHeaderTextStyle,
      ),
    );
  }

  @override
  int numberOfItems(int section) {
    if (section == 0) {
      // fixed section
      return 2;
    }
    return dataSource.getItemCount(section - 1);
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    if (indexPath.section == 0) {
      // fixed section
      return getFixedItem(context, indexPath.item);
    }
    Entity info = dataSource.getItem(indexPath.section - 1, indexPath.item);
    Widget avatar = info.getIcon(null);
    return TableView.cell(
        leading: avatar,
        title: Text(info.name),
        trailing: false,
        onTap: () {
          ProfilePage.open(context, info);
        }
    );
  }

  Widget getFixedItem(BuildContext context, int item) {
    if (item == 0) {
      return TableView.cell(
          leading: Container(
            color: Colors.orange,
            padding: const EdgeInsets.all(2),
            child: const Icon(CupertinoIcons.person_add,
              color: Colors.white,
            ),
          ),
          title: const Text('New Friends'),
          trailing: true,
          onTap: () {
            Alert.show(context, 'Coming soon', 'Requests from new friends.');
          }
      );
    } else if (item == 1) {
      return TableView.cell(
          leading: Container(
            color: Colors.green,
            padding: const EdgeInsets.all(2),
            child: const Icon(CupertinoIcons.person_2,
              color: Colors.white,
            ),
          ),
          title: const Text('Group Chats'),
          trailing: true,
          onTap: () {
            Alert.show(context, 'Coming soon', 'Conversations for groups.');
          }
      );
    }
    // error
    return const Text('error');
  }
}

class _ContactDataSource {

  List<String> sections = [];
  Map<int, List<Entity>> items = {};

  void refresh(List<Entity> contacts) {
    debugPrint('refreshing ${contacts.length} contact(s)');
    ContactSorter sorter = ContactSorter.build(contacts);
    sections = sorter.sectionNames;
    items = sorter.sectionItems;
  }

  int getSectionCount() {
    return sections.length;
  }

  String getSection(int sec) {
    return sections[sec];
  }

  int getItemCount(int sec) {
    List<Entity>? contacts = items[sec];
    return contacts!.length;
  }

  Entity getItem(int sec, int idx) {
    List<Entity>? contacts = items[sec];
    return contacts![idx];
  }
}
