import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../common/constants.dart';
import '../client/shared.dart';

import 'chat.dart';
import 'chat_contact.dart';
import 'chat_group.dart';
import 'shield.dart';
import 'message.dart';

class Amanuensis {
  factory Amanuensis() => _instance;
  static final Amanuensis _instance = Amanuensis._internal();
  Amanuensis._internal();

  ///
  ///  Conversations
  ///

  List<Conversation>? _conversations;
  final Map<ID, Conversation> _conversationMap = WeakValueMap();

  List<Conversation> get conversations {
    List<Conversation>? all = _conversations;
    if (all == null) {
      return [];
    }
    List<Conversation> array = [];
    for (Conversation chat in all) {
      if (chat is GroupInfo) {
        array.add(chat);
      } else if (chat is ContactInfo) {
        if (chat.isBlocked) {
          // skip blocked-list
        } else if (chat.isNotFriend) {
          // skip stranger
        } else {
          array.add(chat);
        }
      }
    }
    return array;
  }

  List<Conversation> get groupChats {
    List<Conversation>? all = _conversations;
    if (all == null) {
      return [];
    }
    List<Conversation> array = [];
    for (Conversation chat in all) {
      if (chat is GroupInfo) {
        array.add(chat);
      }
    }
    return array;
  }

  List<Conversation> get strangers {
    List<Conversation>? all = _conversations;
    if (all == null) {
      return [];
    }
    List<Conversation> array = [];
    for (Conversation chat in all) {
      if (chat is ContactInfo) {
        if (chat.isNewFriend) {
          array.add(chat);
        }
      }
    }
    return array;
  }

  Future<List<Conversation>> loadConversations() async {
    List<Conversation>? array = _conversations;
    if (array == null) {
      GlobalVariable shared = GlobalVariable();
      // get ID list from database
      array = await shared.database.getConversations();
      Log.debug('${array.length} conversation(s) loaded');
      // build conversations
      List<Conversation> temp = [...array];
      for (Conversation item in temp) {
        Log.debug('new conversation created: $item');
        _conversationMap[item.identifier] = item;
      }
      Log.debug('${array.length} conversation(s) loaded: $array');
      _conversations = array;
    }
    return array;
  }

  Future<bool> clearConversation(ID identifier) async {
    GlobalVariable shared = GlobalVariable();
    // 1. clear messages
    if (await shared.database.removeInstantMessages(identifier)) {} else {
      Log.error('failed to clear messages in conversation: $identifier');
      return false;
    }
    // 2. update cache
    Conversation? chat = _conversationMap[identifier];
    if (chat != null) {
      chat.unread = 0;
      chat.lastMessage = null;
      chat.lastMessageTime = null;
      // 3. update database
      if (await shared.database.updateConversation(chat)) {} else {
        Log.error('failed to update conversation: $chat');
        return false;
      }
    }
    // OK
    Log.warning('conversation cleared: $identifier');
    return true;
  }

  Future<bool> removeConversation(ID identifier) async {
    GlobalVariable shared = GlobalVariable();
    // 1. clear messages
    if (await shared.database.removeInstantMessages(identifier)) {} else {
      Log.error('failed to clear messages in conversation: $identifier');
      return false;
    }
    // 2. remove from database
    if (await shared.database.removeConversation(identifier)) {} else {
      Log.error('failed to remove conversation: $identifier');
      return false;
    }
    // 3. remove from cache
    Conversation? chat = _conversationMap[identifier];
    if (chat != null) {
      _conversations?.remove(chat);
      _conversationMap.remove(identifier);
    }
    // OK
    Log.warning('conversation cleared: $identifier');
    return true;
  }

  /// get conversation ID for message envelope
  Future<ID> _cid(Envelope head, Content? body) async {
    // check group
    ID? group = body?.group;
    group ??= head.group;
    if (group != null) {
      // group chat, get chat box with group ID
      return group;
    }
    // check receiver
    ID receiver = head.receiver;
    if (receiver.isGroup) {
      // group chat, get chat box with group ID
      return receiver;
    }
    // personal chat, get chat box with contact ID
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    assert(user != null, 'current user should not be empty here');
    ID sender = head.sender;
    if (sender == user?.identifier) {
      return receiver;
    } else {
      return sender;
    }
  }

  Future<bool> clearUnread(Conversation chatBox) async {
    ID cid = chatBox.identifier;
    int unread = chatBox.unread;
    if (unread == 0) {
      // no need to update
      Log.info('[Badge] unread is zero: $cid');
      return false;
    } else if (_conversationMap[cid] == null) {
      // conversation not found
      Log.warning('[Badge] conversation not found: $cid, unread: $unread');
      return false;
    }
    chatBox.unread = 0;
    GlobalVariable shared = GlobalVariable();
    if (await shared.database.updateConversation(chatBox)) {
      Log.info('[Badge] unread count cleared: $chatBox, unread: $unread');
    } else {
      Log.error('[Badge] failed to update conversation: $chatBox, unread: $unread');
      return false;
    }
    var nc = lnc.NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, null, {
      'action': 'read',
      'ID': cid,
    });
    return true;
  }

  Future<void> _update(ID cid, InstantMessage iMsg) async {
    Shield shield = Shield();
    if (await shield.isBlocked(iMsg.sender, group: iMsg.group)) {
      // this message should have been blocked before verifying by messenger
      Log.error('contact is blocked: ${iMsg.sender}, group: ${iMsg.group}');
      return;
    }
    Content content = iMsg.content;
    DefaultMessageBuilder mb = DefaultMessageBuilder();
    if (mb.isCommand(content, iMsg.sender)) {
      Log.debug('ignore command for conversation updating');
      return;
    }
    String last = mb.getText(content, iMsg.sender);
    if (last.isEmpty) {
      Log.warning('content text empty: $content');
      return;
    } else {
      last = last.replaceAll(RegExp('[\r\n]+'), ' ').trim();
      if (last.length > 200) {
        last = '${last.substring(0, 197)}...';
      }
    }
    DateTime? time = iMsg.time;
    Log.warning('update last message: $last for conversation: $cid');

    GlobalVariable shared = GlobalVariable();
    Conversation? chatBox = _conversationMap[cid];
    if (chatBox == null) {
      // new conversation
      chatBox = Conversation.fromID(cid);
      if (chatBox == null) {
        Log.error('failed to get conversation: $cid');
        return;
      }
      chatBox.unread = 1;
      chatBox.lastMessage = last;
      chatBox.lastMessageTime = time;
      if (await shared.database.addConversation(chatBox)) {
        await chatBox.reloadData();
        // add to cache
        _conversationMap[cid] = chatBox;
        // _conversations?.insert(0, chatBox);
      } else {
        Log.error('failed to add conversation: $chatBox');
        return;
      }
    } else {
      // conversation exists
      if (chatBox.widget == null) {
        chatBox.unread += 1;
      } else {
        Log.warning('chat box is opened for: $cid');
        chatBox.unread = 0;
      }
      chatBox.lastMessage = last;
      chatBox.lastMessageTime = time;
      if (await shared.database.updateConversation(chatBox)) {} else {
        Log.error('failed to update conversation: $chatBox');
        return;
      }
    }
    var nc = lnc.NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'update',
      'ID': cid,
      'msg': iMsg,
    });
  }

  Future<bool> saveInstantMessage(InstantMessage iMsg) async {
    Content content = iMsg.content;
    if (content is ReceiptCommand) {
      // it's a receipt
      return await saveReceipt(iMsg);
    }
    // TODO: check message type
    //       only save normal message and group commands
    //       ignore 'Handshake', ...
    //       return true to allow responding

    if (content is HandshakeCommand) {
      // handshake command will be processed by CPUs
      // no need to save handshake command here
      return true;
    }
    if (content is ReportCommand) {
      // report command is sent to station,
      // no need to save report command here
      return true;
    }
    if (content is LoginCommand) {
      // login command will be processed by CPUs
      // no need to save login command here
      return true;
    }
    if (content is MetaCommand) {
      // meta & document command will be checked and saved by CPUs
      // no need to save meta & document command here
      return true;
    }
    // if (content is MuteCommand || content is BlockCommand) {
    //   // TODO: create CPUs for mute & block command
    //   // no need to save mute & block command here
    //   return true;
    // }
    if (content is SearchCommand) {
      // search result will be parsed by CPUs
      // no need to save search command here
      return true;
    }
    if (content is ForwardContent) {
      // forward content will be parsed, if secret message decrypted, save it
      // no need to save forward content itself
      return true;
    }

    GlobalVariable shared = GlobalVariable();

    if (content is InviteCommand) {
      // send keys again
      ID me = iMsg.receiver;
      ID group = content.group!;
      SymmetricKey? key = await shared.mdb.getCipherKey(sender: me, receiver: group);
      if (key != null) {
        //key.put("reused", null);
        key.remove("reused");
      }
    }
    if (content is QueryCommand) {
      // FIXME: same query command sent to different members?
      return true;
    }

    ID cid = await _cid(iMsg.envelope, iMsg.content);
    bool ok = await shared.database.saveInstantMessage(cid, iMsg);
    if (ok) {
      // TODO: save traces

      // update conversation
      await _update(cid, iMsg);
    }
    return ok;
  }

  /// save receipt for instant message
  Future<bool> saveReceipt(InstantMessage iMsg) async {
    Content content = iMsg.content;
    if (content is! ReceiptCommand) {
      assert(false, 'receipt error: $iMsg');
      return false;
    }
    Envelope? env = content.originalEnvelope;
    if (env == null) {
      Log.error('original envelope not found: $content');
      return false;
    }
    Map mta = {'ID': iMsg.sender.toString(), 'time': content['time']};
    // trace info
    String trace = JSON.encode(mta);
    ID cid = await _cid(env, null);
    ID sender = env.sender;  // original sender
    int? sn = content.originalSerialNumber;
    String? signature = content.originalSignature;
    if (sn == null) {
      sn = 0;
      Log.error('original sn not found: $content, sender: ${iMsg.sender}');
    }
    // save trace
    GlobalVariable shared = GlobalVariable();
    if (await shared.database.addTrace(trace, cid,
        sender: sender, sn: sn, signature: signature)) {} else {
      Log.error('failed to add message trace: ${iMsg.sender} ($sender -> $cid)');
      return false;
    }
    var nc = lnc.NotificationCenter();
    nc.postNotification(NotificationNames.kMessageTraced, this, {
      'cid': cid,
      'sender': sender,
      'sn': sn,
      'signature': signature,
      'mta': mta,
      'text': content.text
    });
    return true;
  }

}
