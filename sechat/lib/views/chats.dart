import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'channels.dart';
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

class _ChatListState extends State<ChatHistoryPage> {
  _ChatListState() {
    dataSource = _ChatListDataSource();
  }

  late final _ChatListDataSource dataSource;

  void reloadData() {
    ChannelManager.instance.conversationChannel.getConversations().then((json) => {
      if (json != null) {
        setState(() {
          dataSource.refresh(Conversation.listFromJson(json));
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
        middle: const Text('Secure Chat'),
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

  final _ChatListDataSource dataSource;

  @override
  int numberOfItems(int section) {
    return dataSource.getItemCount();
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    Conversation info = dataSource.getItem(indexPath.item);
    Widget icon = info.getIcon(null);
    return TableView.cell(
        leading: icon,
        title: Text(info.name),
        trailing: false,
        onTap: () {
          ChatBox.open(context, info);
        }
    );
  }
}

class _ChatListDataSource {

  List<Conversation> conversations = [];

  void refresh(List<Conversation> history) {
    Log.debug('refreshing ${history.length} history(ies)');
    conversations = history;
  }

  int getItemCount() {
    return conversations.length;
  }

  Conversation getItem(int index) {
    return conversations[index];
  }
}
