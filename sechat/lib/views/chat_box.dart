import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'alert.dart';
import 'channels.dart';
import 'styles.dart';

class Envelope {
  final String sender;
  final String receiver;
  final double time;
  Envelope({required this.sender, required this.receiver, this.time = 0});

  @override
  String toString() {
    return '<Envelope sender="$sender" receiver="$receiver" time=$time />';
  }

  static Envelope fromJson(Map json) => Envelope(
    sender: json['sender'],
    receiver: json['receiver'],
    time: getTime(json['time']),
  );

  static double getTime(dynamic time) {
    if (time is double) {
      return time;
    } else if (time is int) {
      return time.toDouble();
    } else if (time is String) {
      return double.parse(time);
    } else {
      // FIXME:
      throw TypeError();
    }
  }
}

class Content {
  final int type;
  final String? text;
  final String? url;
  final String? filename;
  Content({required this.type, this.text, this.url, this.filename});

  @override
  String toString() {
    if (type == 1) {
      return '<TextContent>$text</TextContent>';
    } else {
      return '<Content filename="$filename" url="$url" />';
    }
  }

  static Content fromJson(Map json) => Content(
    type: json['type'],
    text: json['text'],
    url: json['url'],
    filename: json['filename'],
  );
}

class InstantMessage {
  final Envelope envelope;
  final Content content;
  InstantMessage({required this.envelope, required this.content});

  @override
  String toString() {
    return '<InstantMessage>\n$envelope\n$content\n</InstantMessage>';
  }

  static InstantMessage fromJson(Map json) => InstantMessage(
    envelope: Envelope.fromJson(json),
    content: Content.fromJson(json['content']),
  );

  static List<InstantMessage> listFromJson(List json) {
    return json.map((item) => InstantMessage.fromJson(item)).toList();
  }
}

class Conversation {
  final String identifier;
  final int type;
  final String name;
  String? icon;
  Conversation({required this.identifier, required this.type, required this.name, this.icon});

  @override
  String toString() {
    return '<Conversation id="$identifier" type=$type name="$name" icon="$icon" />';
  }

  bool isUser() {
    return type & 1 == 0;
  }
  bool isGroup() {
    return type & 1 == 1;
  }

  Widget getIcon(double? size) {
    if (icon != null) {
      // TODO: build icon
      return Icon(CupertinoIcons.photo, size: size);
    } else if (isGroup()) {
      return Icon(CupertinoIcons.person_2_fill, size: size);
    } else {
      return Icon(CupertinoIcons.profile_circled, size: size);
    }
  }

  //
  //  factories
  //
  static Conversation fromJson(Map json) {
    return Conversation(
      identifier: json['identifier']!,
      name: json['name']!,
      type: json['type'] ?? 0,
      icon: json['icon'],
    );
  }

  static List<Conversation> listFromJson(List json) {
    return json.map((item) => Conversation.fromJson(item)).toList();
  }
}

///
///  Chat Box
///
class ChatBox extends StatefulWidget {
  const ChatBox(this.info, {super.key});

  final Conversation info;

  static void open(BuildContext context, Conversation info) {
    showCupertinoDialog(
      context: context,
      builder: (context) => ChatBox(info),
    );
  }

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  _ChatBoxState() {
    dataSource = _HistoryDataSource();
  }

  TextEditingController textController = TextEditingController();

  late final _HistoryDataSource dataSource;

  void reloadData() {
    ConversationChannel channel = ChannelManager.instance.conversationChannel;
    channel.getMessages(widget.info.identifier).then((json) => {
      if (json != null) {
        setState(() {
          dataSource.refresh(InstantMessage.listFromJson(json));
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
        middle: Text(widget.info.name),
        trailing: IconButton(
          iconSize: Styles.navigationBarIconSize,
          color: Styles.navigationBarIconColor,
          icon: const Icon(Icons.more_horiz),
          onPressed: () => _openDetail(context, widget.info),
        ),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(
        flex: 1,
        child: SectionListView.builder(
          reverse: true,
          adapter: _HistoryAdapter(
              conversation: widget.info,
              dataSource: dataSource,
          ),
        ),
      ),
      _tray(context),
    ],
  );

  Widget _tray(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Expanded(
        flex: 1,
        child: CupertinoTextField(
          controller: textController,
          placeholder: 'Input text message',
          onSubmitted: (value) => _sendText(context, textController),
        ),
      ),
      CupertinoButton(
        child: const Icon(Icons.send),
        onPressed: () => _sendText(context, textController),
      ),
    ],
  );
}

class _HistoryAdapter with SectionAdapterMixin {
  _HistoryAdapter({required this.conversation, required this.dataSource});

  final Conversation conversation;
  final _HistoryDataSource dataSource;

  @override
  int numberOfItems(int section) {
    WeakReference<int> wr;
    return dataSource.getItemCount();
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    InstantMessage info = dataSource.getItem(indexPath.item);
    String sender = info.envelope.sender;
    // TODO: get current user
    String me = 'moky@anywhere';
    bool isMe = sender == me;
    bool isGroupChat = conversation.type & 1 == 1;
    const radius = Radius.circular(12);
    const borderRadius = BorderRadius.all(radius);
    return Container(
      margin: const EdgeInsets.only(left: 8, top: 4, right: 8, bottom: 4),
      // color: Colors.yellowAccent,
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Container(
              width: 48,
              height: 48,
              color: Colors.yellow,
              child: IconButton(
                icon: const Icon(CupertinoIcons.photo),
                onPressed: () => _openProfile(context, sender),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe && (isGroupChat || sender != conversation.identifier))
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: Text(sender,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  color: isMe ? Colors.lightGreen : Colors.white,
                  borderRadius: isMe
                      ? borderRadius.subtract(
                      const BorderRadius.only(topRight: radius))
                      : borderRadius.subtract(
                      const BorderRadius.only(topLeft: radius)),
                ),
                child: Text('$sender: ${info.content}'),
              ),
            ],
          ),
          if (isMe)
            Container(
              color: Colors.yellow,
              child: IconButton(
                icon: const Icon(CupertinoIcons.photo),
                onPressed: () {

                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryDataSource {

  List<InstantMessage> messages = [];

  void refresh(List<InstantMessage> history) {
    debugPrint('refreshing ${history.length} message(s)');
    messages = history.reversed.toList();
  }

  int getItemCount() {
    return messages.length;
  }

  InstantMessage getItem(int index) {
    return messages[index];
  }
}

//--------

void _sendText(BuildContext context, TextEditingController controller) {
  String text = controller.text;
  Alert.show(context, 'Message', text);
  controller.text = '';
}

void _openDetail(BuildContext context, Conversation info) {
  Alert.show(context, 'Coming soon', 'show detail: $info');
}

void _openProfile(BuildContext context, String uid) {
  Alert.show(context, 'Coming soon', 'show profile: $uid');
}
