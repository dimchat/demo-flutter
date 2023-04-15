import '../client/filesys/paths.dart';
import '../models/local.dart';
import 'conversation.dart';
import 'helper/sqlite.dart';


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
          "cid VARCHAR(64)",
          "unread INTEGER",     // count of unread messages
          "last VARCHAR(128)",  // desc of last message
          "time INTEGER",       // time of last message
        ]);
        // instant message
        DatabaseConnector.createTable(db, tInstantMessage, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64)",
          "sender VARCHAR(64)",
          // "receiver VARCHAR(64)",
          "time INTEGER",
          "type INTEGER",
          "sn INTEGER",
          "signature VARCHAR(8)",  // last 8 characters
          // "content TEXT",
          "msg TEXT",
          "read BIT",
        ]);
        DatabaseConnector.createIndex(db, tInstantMessage,
            name: 'cid_index', fields: ['cid']);
        DatabaseConnector.createTable(db, tTrace, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64)",
          "sn INTEGER",
          "signature VARCHAR(8)",  // last 8 characters
          "trace TEXT",
        ]);
        DatabaseConnector.createIndex(db, tTrace,
            name: 'trace_id_index', fields: ['cid']);
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


ID _extractChatBox(ResultSet resultSet, int index) {
  String user = resultSet.getString('cid');
  return ID.parse(user)!;
}


class ConversationTable extends DataTableHandler<ID> implements ConversationDBI {
  ConversationTable() : super(MessageDatabase(), _extractChatBox);

  static const String _table = MessageDatabase.tChatBox;
  static const List<String> _selectColumns = ["cid", "unread", "last", "time"];
  static const List<String> _insertColumns = ["cid", "unread", "last", "time"];

  @override
  Future<List<ID>> getConversations() async {
    SQLConditions cond = SQLConditions.kTrue;
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC');
  }

  @override
  Future<bool> addConversation(ID chat) async {
    List values = [chat.string, 0, '', 0];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> removeConversation(ID chat) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.string);
    return await delete(_table, conditions: cond) > 0;
  }

}


InstantMessage _extractInstantMessage(ResultSet resultSet, int index) {
  String json = resultSet.getString('msg');
  int read = resultSet.getInt('read');
  Map? msg = JSONMap.decode(json);
  InstantMessage iMsg = InstantMessage.parse(msg)!;
  iMsg['read'] = read;
  return iMsg;
}


class InstantMessageTable extends DataTableHandler<InstantMessage> implements InstantMessageDBI {
  InstantMessageTable() : super(MessageDatabase(), _extractInstantMessage);

  static const String _table = MessageDatabase.tInstantMessage;
  static const List<String> _selectColumns = ["cid", "msg", "read"];
  static const List<String> _insertColumns = ["cid", "sender",/* "receiver",*/
    "time", "type", "sn", "signature",/* "content",*/ "msg", "read"];

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
    int read = iMsg.getInt('read');
    List values = [chat.string, sender,/* receiver,*/ time, iMsg.type,
      content.sn, sig, /*content.dictionary,*/ iMsg.dictionary, read];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  @override
  Future<bool> removeInstantMessage(ID chat, InstantMessage iMsg) async {
    String sender = iMsg.sender.string;
    Content content = iMsg.content;
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.string);
    cond.addCondition(SQLConditions.kAnd, left: 'sender', comparison: '=', right: sender);
    cond.addCondition(SQLConditions.kAnd, left: 'sn', comparison: '=', right: content.sn);
    return await delete(_table, conditions: cond) > 0;
  }

}


// TODO: accessing 't_trace'


ReliableMessage _extractReliableMessage(ResultSet resultSet, int index) {
  String json = resultSet.getString('msg');
  Map? msg = JSONMap.decode(json);
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
