import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/messenger.dart';
import '../client/protocol/search.dart';
import '../client/session.dart';
import '../client/shared.dart';
import '../models/contact.dart';
import '../widgets/alert.dart';
import 'profile.dart';
import 'styles.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  static Widget searchButton(BuildContext context) => IconButton(
    iconSize: Styles.navigationBarIconSize,
    color: Styles.navigationBarIconColor,
    icon: const Icon(CupertinoIcons.search),
    onPressed: () => open(context),
  );

  static void open(BuildContext context) => showCupertinoDialog(
    context: context,
    builder: (context) => const SearchPage(),
  );

  @override
  State<StatefulWidget> createState() => _SearchState();

}

class _SearchState extends State<SearchPage> implements lnc.Observer {
  _SearchState() {
    _dataSource = _SearchDataSource();
    _adapter = _SearchResultAdapter(this, dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kServerStateChanged);
    nc.addObserver(this, NotificationNames.kSearchUpdated);
  }

  late final _SearchDataSource _dataSource;
  late final _SearchResultAdapter _adapter;
  int _sessionState = 0;

  int _searchTag = 0;

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kSearchUpdated);
    nc.removeObserver(this, NotificationNames.kServerStateChanged);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kServerStateChanged) {
      int state = info!['state'];
      setState(() {
        _sessionState = state;
      });
    } else if (name == NotificationNames.kSearchUpdated) {
      _reload(info?['cmd']);
    }
  }

  Future<void> _reload(SearchCommand? command) async {
    GlobalVariable shared = GlobalVariable();
    SessionState? state = shared.terminal.session?.state;
    if (state != null) {
      _sessionState = state.index;
    }
    if (command == null) {
      return;
    }
    List? users = command['users'];
    if (users == null) {
      Log.error('users not found in search response');
      return;
    }
    int? tag = command['tag'];
    Log.debug('respond with search tag: $tag');
    if (tag != _searchTag) {
      Log.error('search tag not match, ignore this response: $tag <> $_searchTag');
      return;
    }
    List<ContactInfo> array = await ContactInfo.fromList(ID.convert(users));
    setState(() {
      _dataSource.refresh(array);
      _adapter.notifyDataChange();
    });
  }

  @override
  void initState() {
    super.initState();
    _reload(null);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text(titleWithState('Search User', _sessionState)),
    ),
    child: SectionListView.builder(
      adapter: _adapter,
    ),
  );

  Widget _searchWidget(BuildContext context) => CupertinoSearchTextField(
    onSubmitted: (value) => _search(context, value),
  );

  Future<void> _search(BuildContext context, keywords) async {
    Log.warning('TODO: search $keywords');
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set, not connect yet?');
      Alert.show(context, 'Error', 'Failed to send command');
      return;
    } else {
      setState(() {
        _dataSource.refresh([]);
        _adapter.notifyDataChange();
      });
    }
    // build command
    SearchCommand command = SearchCommand.fromKeywords(keywords);
    _searchTag = command.sn;
    command['tag'] = _searchTag;
    // check visa.key
    ID? bot = ClientFacebook.ans?.identifier("archivist");
    if (bot == null || await shared.facebook.getPublicKeyForEncryption(bot) == null) {
      // TODO: query station with 'ans'/'document' command for bot ID
      bot = ID.parse("archivist@anywhere");
    }
    Log.debug('query with search tag: $_searchTag');
    messenger.sendContent(command, sender: null, receiver: bot!);
  }
}

class _SearchResultAdapter with SectionAdapterMixin {
  _SearchResultAdapter(this.state, {required _SearchDataSource dataSource})
      : _dataSource = dataSource;

  final _SearchDataSource _dataSource;
  final _SearchState state;

  @override
  bool shouldExistSectionHeader(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) =>
      state._searchWidget(context);

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    ContactInfo info = _dataSource.getItem(indexPath.section - 1, indexPath.item);
    return ProfilePage.cell(info);
  }

}

class _SearchDataSource {

  List<ContactInfo>? _items;

  Future<void> refresh(List<ContactInfo> array) async {
    Log.debug('refreshing ${array.length} search result(s)');
    _items = array;
  }

  int getSectionCount() => 1;

  int getItemCount(int sec) => _items?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items![idx];

}
