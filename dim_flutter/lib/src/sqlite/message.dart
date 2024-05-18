import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:pnf/dos.dart';

import '../common/dbi/message.dart';
import '../common/constants.dart';
import '../common/platform.dart';
import '../filesys/local.dart';
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
          "cid VARCHAR(64) NOT NULL UNIQUE",
          "unread INTEGER",     // count of unread messages
          "last VARCHAR(128)",  // desc of last message
          "time INTEGER",       // time of last message (seconds)
          "mentioned INTEGER",  // sn
        ]);
        // instant message
        DatabaseConnector.createTable(db, tInstantMessage, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64) NOT NULL",
          "sender VARCHAR(64)",
          // "receiver VARCHAR(64)",
          "time INTEGER NOT NULL",  // time of message (seconds)
          "type INTEGER",
          "sn INTEGER",
          "signature VARCHAR(8)",   // last 8 characters
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
        if (oldVersion < 2) {
          // add column for conversation
          DatabaseConnector.addColumn(db, tChatBox, name: 'mentioned', type: 'INTEGER');
        }
      });

  static const String dbName = 'msg.db';
  static const int dbVersion = 2;

  static const String tChatBox         = 't_conversation';

  static const String tInstantMessage  = 't_message';
  static const String tTrace           = 't_trace';

  static const String tReliableMessage = 't_reliable_message';

  /// returns: '{caches}/.dkd/msg.db'
  @override
  Future<String?> get path async {
    if (DevicePlatform.isWeb) {
      return await super.path;
    }
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
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.toString());
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
    String cid = chat.toString();
    String sender = iMsg.sender.toString();
    // String receiver = iMsg.receiver.string;
    int? time = iMsg.time?.millisecondsSinceEpoch;
    if (time == null) {
      time = 0;
    } else {
      time = time ~/ 1000;
    }
    Content content = iMsg.content;
    String? sig = iMsg.getString('signature', null);
    if (sig != null) {
      sig = sig.substring(sig.length - 8);
    }
    String msg = JSON.encode(iMsg.toMap());

    // check old record
    SQLConditions cond;
    cond = SQLConditions(left: 'sn', comparison: '=', right: content.sn);
    cond.addCondition(SQLConditions.kAnd, left: 'cid', comparison: '=', right: cid);
    cond.addCondition(SQLConditions.kAnd, left: 'sender', comparison: '=', right: sender);
    List<InstantMessage> messages = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);

    if (messages.isEmpty) {
      // add new message
      List values = [cid, sender,/* receiver,*/ time, iMsg.type,
        content.sn, sig, /*JSON.encode(content.dictionary),*/ msg];
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

    // check message time
    DateTime? oldTime = messages.last.time;
    DateTime? newTime = iMsg.time;
    if (oldTime != null && newTime != null && newTime.isBefore(oldTime)) {
      Log.warning('ignore expired message: $iMsg');
      return false;
    }

    // update old message
    Map<String, dynamic> values = {
      // 'cid': chat.string,
      // 'sender': sender,
      // // 'receiver': receiver,
      'time': time,
      'type': iMsg.type,
      // 'sn': content.sn,
      'signature': sig,
      // 'content': JSON.encode(content.dictionary),
      'msg': msg,
    };
    if (await update(_table, values: values, conditions: cond) < 1) {
      Log.error('failed to update message: $sender -> $chat');
      return false;
    }
    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageUpdated, this, {
      'action': 'update',
      'ID': chat,
      'msg': iMsg,
    });
    return true;
  }

  @override
  Future<bool> removeInstantMessage(ID chat, InstantMessage iMsg) async {
    String sender = iMsg.sender.toString();
    Content content = iMsg.content;
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.toString());
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

  @override
  Future<bool> removeInstantMessages(ID chat) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.toString());
    if (await delete(_table, conditions: cond) < 0) {
      Log.error('failed to remove messages: $chat');
      return false;
    }
    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageUpdated, this, {
      'action': 'clear',
      'ID': chat,
    });
    return true;
  }

  Future<int> burnMessages(DateTime expired) async {
    int time = expired.millisecondsSinceEpoch ~/ 1000;
    SQLConditions cond;
    cond = SQLConditions(left: 'time', comparison: '<', right: time);
    int results = await delete(_table, conditions: cond);
    if (results < 0) {
      Log.error('failed to remove expired messages: $expired');
      return results;
    }
    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageCleaned, this, {
      'action': 'burn',
      'expired': expired,
      'results': results,
    });
    return results;
  }

}
