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
import 'tableview.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  static BottomNavigationBarItem barItem() {
    return const BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.chat_bubble_2),
      label: 'Chats',
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _ChatListState();
  }
}

class _ChatListState extends State<ChatHistoryPage> implements lnc.Observer {
  _ChatListState() : dataSource = Amanuensis() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kServerStateChanged);
  }

  final Amanuensis dataSource;

  int _sessionState = 0;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    Map? info = notification.userInfo;
    int state = info!['state'];
    setState(() {
      _sessionState = state;
    });
  }

  void reloadData() {
    GlobalVariable shared = GlobalVariable();
    SessionState? state = shared.terminal.session?.state;
    if (state != null) {
      _sessionState = state.index;
    }
    dataSource.loadConversations().then((value) => setState);
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
        middle: Text(titleWithState('Secure Chat', _sessionState)),
        trailing: SearchPage.searchButton(context),
      ),
      body: SectionListView.builder(
        adapter: _ChatListAdapter(dataSource: dataSource),
      ),
    );
  }
}

class _ChatListAdapter with SectionAdapterMixin {
  _ChatListAdapter({required this.dataSource});

  final Amanuensis dataSource;

  @override
  int numberOfItems(int section) {
    return dataSource.numberOfConversation;
  }

  Widget? _timeLabel(DateTime? time) {
    if (time == null) {
      return null;
    }
    return Text(Time.getTimeString(time), style: Styles.sectionItemTrailingTextStyle);
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    Conversation info = dataSource.conversationAtIndex(indexPath.item);
    Widget cell = TableView.cell(
        leading: info.getIcon(null),
        title: Text(info.name),
        trailing: _timeLabel(info.lastTime),
        onTap: () {
          ChatBox.open(context, info);
        }
    );
    return cell;
  }
}
