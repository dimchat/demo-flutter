import '../client/constants.dart';
import '../client/filesys/paths.dart';
import '../models/conversation.dart';
import '../models/local.dart';
import 'helper/sqlite.dart';


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

abstract class InstantMessageDBI {

  ///  Get stored messages
  ///
  /// @param chat  - conversation ID
  /// @param start - start position for loading message
  /// @param limit - max count for loading message
  /// @return partial messages and remaining count, 0 means there are all messages cached
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat,
      {int start = 0, int? limit});

  ///  Save the message
  ///
  /// @param chat - conversation ID
  /// @param iMsg - instant message
  /// @return true on success
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg);

  ///  Delete the message
  ///
  /// @param chat - conversation ID
  /// @param iMsg - instant message
  /// @return true on row(s) affected
  Future<bool> removeInstantMessage(ID chat, InstantMessage iMsg);

}


///
///  Store messages
///
///     file path: '{sdcard}/Android/data/chat.dim.sechat/files/.dkd/msg.db'
///


class MessageDatabase extends DatabaseConnector {
  MessageDatabase() : super(name: dbName, directory: '.dkd', version: dbVersion,
      onCreate: (db, version) {
        // conversation
        DatabaseConnector.createTable(db, tChatBox, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64) NOT NULL UNIQUE",
          "unread INTEGER",     // count of unread messages
          "last VARCHAR(128)",  // desc of last message
          "time INTEGER",       // time of last message
        ]);
        // instant message
        DatabaseConnector.createTable(db, tInstantMessage, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64) NOT NULL",
          "sender VARCHAR(64)",
          // "receiver VARCHAR(64)",
          "time INTEGER NOT NULL",
          "type INTEGER",
          "sn INTEGER",
          "signature VARCHAR(8)",  // last 8 characters
          // "content TEXT",
          "msg TEXT NOT NULL",
        ]);
        DatabaseConnector.createIndex(db, tInstantMessage,
            name: 'cid_index', fields: ['cid']);
        DatabaseConnector.createTable(db, tTrace, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64) NOT NULL",
          "sender VARCHAR(64) NOT NULL",
          "sn INTEGER NOT NULL",
          "signature VARCHAR(8)",  // last 8 characters
          "trace TEXT NOT NULL",
        ]);
        DatabaseConnector.createIndex(db, tTrace,
            name: 'trace_index', fields: ['sender']);
        // reliable message
      }, onUpgrade: (db, oldVersion, newVersion) {
        // TODO:
      });

  static const String dbName = 'msg.db';
  static const int dbVersion = 1;

  static const String tChatBox         = 't_conversation';

  static const String tInstantMessage  = 't_message';
  static const String tTrace           = 't_trace';

  static const String tReliableMessage = 't_reliable_message';

  /// returns: '{caches}/.dkd/msg.db'
  @override
  Future<String?> get path async {
    String root = await LocalStorage().cachesDirectory;
    String dir = Paths.append(root, directory);
    if (await Paths.mkdirs(dir)) {
      // make sure parent directory exists
      Log.debug('created: $dir');
    } else {
      Log.error('failed to create directory: $dir');
      return null;
    }
    Log.debug('external database: $name in $dir');
    return Paths.append(dir, name);
  }

}


Conversation _extractConversation(ResultSet resultSet, int index) {
  String? cid = resultSet.getString('cid');
  int? unread = resultSet.getInt('unread');
  String? last = resultSet.getString('last');
  double? seconds = resultSet.getDouble('time');
  DateTime? time;
  if (seconds != null) {
    time = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).toInt());
  }
  return Conversation(ID.parse(cid)!, unread: unread!, lastMessage: last, lastTime: time);
}


class ConversationTable extends DataTableHandler<Conversation> implements ConversationDBI {
  ConversationTable() : super(MessageDatabase(), _extractConversation);

  static const String _table = MessageDatabase.tChatBox;
  static const List<String> _selectColumns = ["cid", "unread", "last", "time"];
  static const List<String> _insertColumns = ["cid", "unread", "last", "time"];

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
      DateTime? at = a.lastTime;
      DateTime? bt = b.lastTime;
      int ai = at == null ? 0 : at.millisecondsSinceEpoch;
      int bi = bt == null ? 0 : bt.millisecondsSinceEpoch;
      return bi - ai;
    });
  }

  @override
  Future<List<Conversation>> getConversations() async {
    List<Conversation>? conversations = _caches;
    if (conversations == null) {
      // cache not found, try to load from database
      SQLConditions cond = SQLConditions.kTrue;
      conversations = await select(_table, columns: _selectColumns,
          conditions: cond, orderBy: 'time DESC');
      // add to cache
      _caches = conversations;
    }
    return conversations;
  }

  @override
  Future<bool> addConversation(Conversation chat) async {
    // 1. check cache
    List<Conversation>? array = await getConversations();
    if (_find(chat.identifier, array) != null) {
      assert(false, 'duplicated conversation: $chat');
      return false;
    }
    // 2. add new record
    double? seconds;
    if (chat.lastTime != null) {
      seconds = chat.lastTime!.millisecondsSinceEpoch / 1000.0;
    }
    List values = [chat.identifier.string, chat.unread, chat.lastMessage, seconds];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      Log.error('failed to add conversation: $chat');
      return false;
    }
    // add to cache
    array.insert(0, chat);
    _sort(array);
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
    double? seconds;
    if (chat.lastTime != null) {
      seconds = chat.lastTime!.millisecondsSinceEpoch / 1000.0;
    }
    Map<String, dynamic> values = {
      'unread': chat.unread,
      'last': chat.lastMessage,
      'time': seconds,
    };
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.identifier.string);
    if (await update(_table, values: values, conditions: cond) != 1) {
      Log.error('failed to update conversation: $chat');
      return false;
    }
    // update cache
    if (!identical(old, chat)) {
      old.name = chat.name;
      old.image = chat.image;
      old.unread = chat.unread;
      old.lastTime = chat.lastTime;
      old.lastMessage = chat.lastMessage;
    }
    _sort(array);
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
      assert(false, 'conversation not found: $chat');
      return false;
    }
    // 2. remove record
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.string);
    if (await delete(_table, conditions: cond) != 1) {
      Log.error('failed to delete conversation: $chat');
      return false;
    }
    // remove from cache
    array.remove(old);
    // 3. post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'remove',
      'ID': chat,
    });
    return true;
  }

}


InstantMessage _extractInstantMessage(ResultSet resultSet, int index) {
  String? json = resultSet.getString('msg');
  Map? msg = JSONMap.decode(json!);
  return InstantMessage.parse(msg)!;
}


class InstantMessageTable extends DataTableHandler<InstantMessage> implements InstantMessageDBI {
  InstantMessageTable() : super(MessageDatabase(), _extractInstantMessage);

  static const String _table = MessageDatabase.tInstantMessage;
  static const List<String> _selectColumns = ["msg"];
  static const List<String> _insertColumns = ["cid", "sender",/* "receiver",*/
    "time", "type", "sn", "signature",/* "content",*/ "msg"];

  @override
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat,
      {int start = 0, int? limit}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.string);
    List<InstantMessage> messages = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC');
    int remaining = 0;
    if (limit != null && limit == messages.length) {
      // TODO: get number of remaining messages
    }
    return Pair(messages, remaining);
  }

  @override
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg) async {
    String sender = iMsg.sender.string;
    // String receiver = iMsg.receiver.string;
    int? time = iMsg.time?.millisecondsSinceEpoch;
    Content content = iMsg.content;
    String? sig = iMsg.getString('signature');
    if (sig != null) {
      sig = sig.substring(sig.length - 8);
    }
    String msg = JSON.encode(iMsg.dictionary);
    List values = [chat.string, sender,/* receiver,*/ time, iMsg.type,
      content.sn, sig, /*content.dictionary,*/ msg];
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      Log.error('failed to save message: $sender -> $chat');
      return false;
    }
    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageUpdated, this, {
      'action': 'add',
      'ID': chat,
      'msg': iMsg,
    });
    return true;
  }

  @override
  Future<bool> removeInstantMessage(ID chat, InstantMessage iMsg) async {
    String sender = iMsg.sender.string;
    Content content = iMsg.content;
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.string);
    cond.addCondition(SQLConditions.kAnd, left: 'sender', comparison: '=', right: sender);
    cond.addCondition(SQLConditions.kAnd, left: 'sn', comparison: '=', right: content.sn);
    if (await delete(_table, conditions: cond) < 0) {
      Log.error('failed to remove message: $sender -> $chat');
      return false;
    }
    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageUpdated, this, {
      'action': 'remove',
      'ID': chat,
      'msg': iMsg,
    });
    return true;
  }

}


ReliableMessage _extractReliableMessage(ResultSet resultSet, int index) {
  String? json = resultSet.getString('msg');
  Map? msg = JSONMap.decode(json!);
  return ReliableMessage.parse(msg)!;
}


class ReliableMessageTable extends DataTableHandler<ReliableMessage> implements ReliableMessageDBI {
  ReliableMessageTable() : super(MessageDatabase(), _extractReliableMessage);

  @override
  Future<Pair<List<ReliableMessage>, int>> getReliableMessages(ID receiver, {int start = 0, int? limit}) async {
    // TODO: implement getReliableMessages
    Log.error('implement getReliableMessages: $receiver');
    return const Pair([], 0);
  }

  @override
  Future<bool> cacheReliableMessage(ID receiver, ReliableMessage rMsg) async {
    // TODO: implement cacheReliableMessage
    Log.error('implement cacheReliableMessage: $receiver');
    return false;
  }

  @override
  Future<bool> removeReliableMessage(ID receiver, ReliableMessage rMsg) async {
    // TODO: implement removeReliableMessage
    Log.error('implement removeReliableMessage: $receiver');
    return false;
  }

}
