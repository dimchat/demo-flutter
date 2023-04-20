import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/session.dart';
import '../client/shared.dart';
import '../models/conversation.dart';
import 'chat_box.dart';
import 'search.dart';
import 'styles.dart';
import '../widgets/tableview.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  static BottomNavigationBarItem barItem() {
    return const BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.chat_bubble_2),
      label: 'Chats',
    );
  }

  @override
  State<StatefulWidget> createState() => _ChatListState();
}

class _ChatListState extends State<ChatHistoryPage> implements lnc.Observer {
  _ChatListState() : _clerk = Amanuensis() {
    _adapter = _ChatListAdapter(dataSource: _clerk);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kServerStateChanged);
    nc.addObserver(this, NotificationNames.kConversationUpdated);
  }

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kServerStateChanged);
    nc.removeObserver(this, NotificationNames.kConversationUpdated);
  }

  final Amanuensis _clerk;

  late final _ChatListAdapter _adapter;
  late SectionListView _listView;

  int _sessionState = 0;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kServerStateChanged) {
      int state = info!['state'];
      setState(() {
        _sessionState = state;
      });
    } else if (name == NotificationNames.kConversationUpdated) {
      await _reload();
      Log.warning('conversation updated');
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    SessionState? state = shared.terminal.session?.state;
    if (state != null) {
      _sessionState = state.index;
    }
    await _clerk.loadConversations().then((value) {
      setState(() {
        _adapter.notifyDataChange();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    _listView = SectionListView.builder(
      adapter: _adapter,
    );
    return Scaffold(
      backgroundColor: Styles.backgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Styles.navigationBarBackground,
        border: Styles.navigationBarBorder,
        middle: Text(titleWithState('Secure Chat', _sessionState)),
        trailing: SearchPage.searchButton(context),
      ),
      body: _listView,
    );
  }
}

class _ChatListAdapter with SectionAdapterMixin {
  _ChatListAdapter({required Amanuensis dataSource}) : _dataSource = dataSource;

  final Amanuensis _dataSource;

  @override
  int numberOfItems(int section) => _dataSource.numberOfConversation;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    Conversation info = _dataSource.conversationAtIndex(indexPath.item);
    Log.warning('show item: $info');
    Widget cell = TableView.cell(
        leading: info.getImage(),
        title: Text(info.name),
        subtitle: _lastMessage(info.lastMessage),
        trailing: _timeLabel(info.lastTime),
        onTap: () {
          Log.warning('tap: $info');
          ChatBox.open(context, info.identifier);
        }
    );
    return cell;
  }

  Widget? _lastMessage(String? last) {
    if (last == null) {
      return null;
    }
    return Text(last);
  }

  Widget? _timeLabel(DateTime? time) {
    if (time == null) {
      return null;
    }
    return Text(Time.getTimeString(time), style: Styles.sectionItemTrailingTextStyle);
  }
}
