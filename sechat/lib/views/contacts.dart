import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/session.dart';
import '../client/shared.dart';
import '../models/contact.dart';
import 'profile.dart';
import 'search.dart';
import 'styles.dart';

class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  static BottomNavigationBarItem barItem() => const BottomNavigationBarItem(
    icon: Icon(CupertinoIcons.group),
    label: 'Contacts',
  );

  @override
  State<StatefulWidget> createState() => _ContactListState();
}

class _ContactListState extends State<ContactListPage> implements lnc.Observer {
  _ContactListState() {
    _dataSource = _ContactDataSource();
    _adapter = _ContactListAdapter(dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kServerStateChanged);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
  }

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    nc.removeObserver(this, NotificationNames.kServerStateChanged);
  }

  late final _ContactDataSource _dataSource;
  late final _ContactListAdapter _adapter;

  int _sessionState = 0;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kServerStateChanged) {
      int state = info!['state'];
      if (mounted) {
        setState(() {
          _sessionState = state;
        });
      }
    } else if (name == NotificationNames.kContactsUpdated) {
      _reload();
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    SessionState? state = shared.terminal.session?.state;
    if (state != null) {
      _sessionState = state.index;
    }
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not set');
      return;
    }
    List<ID> contacts = await shared.database.getContacts(user: user.identifier);
    List<ContactInfo> array = await ContactInfo.fromList(contacts);
    if (mounted) {
      setState(() {
        _dataSource.refresh(array);
        _adapter.notifyDataChange();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.backgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.navigationBarBackground,
      border: Styles.navigationBarBorder,
      middle: Text(titleWithState('Contacts', _sessionState)),
      trailing: SearchPage.searchButton(context),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _ContactListAdapter with SectionAdapterMixin {
  _ContactListAdapter({required _ContactDataSource dataSource})
      : _dataSource = dataSource;

  final _ContactDataSource _dataSource;

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount();// + 1;  // includes fixed section

  @override
  bool shouldExistSectionHeader(int section) => true;//section > 0;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    // if (section == 0) {
    //   // fixed section
    //   return const Text('...');
    // }
    String title = _dataSource.getSection(section);// - 1);
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
    // if (section == 0) {
    //   // fixed section
    //   return 2;
    // }
    return _dataSource.getItemCount(section);// - 1);
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section;// - 1;
    int index = indexPath.item;
    // if (indexPath.section == 0) {
    //   // fixed section
    //   return _fixedItem(context, index);
    // }
    ContactInfo info = _dataSource.getItem(section, index);
    return ProfilePage.cell(info);
  }

  /*
  Widget _fixedItem(BuildContext context, int item) {
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
          trailing: TableView.defaultTrailing,
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
          trailing: TableView.defaultTrailing,
          onTap: () {
            Alert.show(context, 'Coming soon', 'Conversations for groups.');
          }
      );
    } else {
      // error
      return const Text('error');
    }
  }
   */
}

class _ContactDataSource {

  List<String> _sections = [];
  Map<int, List<ContactInfo>> _items = {};

  void refresh(List<ContactInfo> contacts) {
    Log.debug('refreshing ${contacts.length} contact(s)');
    ContactSorter sorter = ContactSorter.build(contacts);
    _sections = sorter.sectionNames;
    _items = sorter.sectionItems;
  }

  int getSectionCount() => _sections.length;

  String getSection(int sec) => _sections[sec];

  int getItemCount(int sec) => _items[sec]?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items[sec]![idx];
}
