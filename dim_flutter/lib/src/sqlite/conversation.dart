import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';

import '../common/constants.dart';
import '../models/chat.dart';
import '../models/chat_contact.dart';
import '../models/chat_group.dart';
import 'helper/sqlite.dart';

import 'message.dart';


abstract class ConversationDBI {

  ///  Get all conversations
  ///
  /// @return chat box ID list
  Future<List<Conversation>> getConversations();

  ///  Add conversation
  ///
  /// @param chat - conversation info
  /// @return true on success
  Future<bool> addConversation(Conversation chat);

  ///  Update conversation
  ///
  /// @param chat - conversation info
  /// @return true on success
  Future<bool> updateConversation(Conversation chat);

  ///  Remove conversation
  ///
  /// @param chat - conversation ID
  /// @return true on success
  Future<bool> removeConversation(ID chat);

}


Conversation _extractConversation(ResultSet resultSet, int index) {
  String? cid = resultSet.getString('cid');
  int? unread = resultSet.getInt('unread');
  String? last = resultSet.getString('last');
  DateTime? time = resultSet.getDateTime('time');
  int mentioned = resultSet.getInt('mentioned') ?? 0;
  ID identifier = ID.parse(cid)!;
  if (identifier.isGroup) {
    return GroupInfo(identifier, unread: unread!,
        lastMessage: last, lastMessageTime: time, mentionedSerialNumber: mentioned);
  }
  return ContactInfo(identifier, unread: unread!,
      lastMessage: last, lastMessageTime: time, mentionedSerialNumber: mentioned);
}


class _ConversationTable extends DataTableHandler<Conversation> implements ConversationDBI {
  _ConversationTable() : super(MessageDatabase(), _extractConversation);

  static const String _table = MessageDatabase.tChatBox;
  static const List<String> _selectColumns = ["cid", "unread", "last", "time", "mentioned"];
  static const List<String> _insertColumns = ["cid", "unread", "last", "time", "mentioned"];

  @override
  Future<List<Conversation>> getConversations() async {
    SQLConditions cond = SQLConditions.kTrue;
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC');
  }

  @override
  Future<bool> addConversation(Conversation chat) async {
    double? seconds;
    if (chat.lastMessageTime != null) {
      seconds = chat.lastMessageTime!.millisecondsSinceEpoch / 1000.0;
    }
    List values = [chat.identifier.toString(), chat.unread,
      chat.lastMessage, seconds, chat.mentionedSerialNumber];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> updateConversation(Conversation chat) async {
    int? time = chat.lastMessageTime?.millisecondsSinceEpoch;
    if (time == null) {
      time = 0;
    } else {
      time = time ~/ 1000;
    }
    Map<String, dynamic> values = {
      'unread': chat.unread,
      'last': chat.lastMessage,
      'time': time,
      'mentioned': chat.mentionedSerialNumber,
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.identifier.toString());
    return await update(_table, values: values, conditions: cond) > 0;
  }

  @override
  Future<bool> removeConversation(ID chat) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.toString());
    return await delete(_table, conditions: cond) >= 0;
  }

  Future<int> burnConversations(DateTime expired) async {
    int time = expired.millisecondsSinceEpoch ~/ 1000;
    Map<String, dynamic> values = {
      'unread': 0,
      'last': '',
      'mentioned': 0,
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'time', comparison: '<', right: time);
    return await update(_table, values: values, conditions: cond);
  }

}

class ConversationCache extends _ConversationTable {

  List<Conversation>? _caches;

  static Conversation? _find(ID chat, List<Conversation> array) {
    for (var item in array) {
      if (item.identifier == chat) {
        return item;
      }
    }
    return null;
  }
  static void _sort(List<Conversation> array) {
    array.sort((a, b) {
      DateTime? at = a.lastMessageTime;
      DateTime? bt = b.lastMessageTime;
      int ai = at == null ? 0 : at.millisecondsSinceEpoch;
      int bi = bt == null ? 0 : bt.millisecondsSinceEpoch;
      return bi - ai;
    });
  }

  @override
  Future<List<Conversation>> getConversations() async {
    List<Conversation>? conversations;
    await lock();
    try {
      conversations = _caches;
      if (conversations == null) {
        // cache not found, try to load from database
        conversations = await super.getConversations();
        // add to cache
        _caches = conversations;
      }
    } finally {
      unlock();
    }
    return conversations;
  }

  @override
  Future<bool> addConversation(Conversation chat) async {
    // 1. check cache
    List<Conversation>? array = await getConversations();
    if (_find(chat.identifier, array) != null) {
      assert(false, 'duplicated conversation: $chat');
      return updateConversation(chat);
    }
    // 2. insert as new record
    if (await super.addConversation(chat)) {
      // add to cache
      array.insert(0, chat);
      _sort(array);
    } else {
      Log.error('failed to add conversation: $chat');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'add',
      'ID': chat.identifier,
    });
    return true;
  }

  @override
  Future<bool> updateConversation(Conversation chat) async {
    // 1. check cache
    List<Conversation>? array = await getConversations();
    Conversation? old = _find(chat.identifier, array);
    if (old == null) {
      assert(false, 'conversation not found: $chat');
      return false;
    }
    // 2. update record
    if (await super.updateConversation(chat)) {
      // update cache
      if (!identical(old, chat)) {
        old.unread = chat.unread;
        old.lastMessageTime = chat.lastMessageTime;
        old.lastMessage = chat.lastMessage;
        old.mentionedSerialNumber = chat.mentionedSerialNumber;
      }
      _sort(array);
    } else {
      Log.error('failed to update conversation: $chat');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'update',
      'ID': chat.identifier,
    });
    return true;
  }

  @override
  Future<bool> removeConversation(ID chat) async {
    // 1. check cache
    List<Conversation>? array = await getConversations();
    Conversation? old = _find(chat, array);
    if (old == null) {
      Log.warning('conversation not found: $chat');
      return false;
    }
    // 2. remove record
    if (await super.removeConversation(chat)) {
      // remove from cache
      array.remove(old);
    } else {
      Log.error('failed to delete conversation: $chat');
      return false;
    }
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'remove',
      'ID': chat,
    });
    return true;
  }

  @override
  Future<int> burnConversations(DateTime expired) async {
    int results = await super.burnConversations(expired);
    if (results < 0) {
      Log.error('failed to clean expired conversations: $expired');
      return results;
    }
    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationCleaned, this, {
      'action': 'burn',
      'expired': expired,
      'results': results,
    });
    return results;
  }

}
