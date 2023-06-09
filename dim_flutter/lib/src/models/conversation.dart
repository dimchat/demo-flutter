import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/facebook.dart';
import '../client/messenger.dart';
import '../client/shared.dart';

import 'contact.dart';
import 'shield.dart';
import 'message.dart';


class Conversation extends ContactInfo {
  Conversation(super.identifier,
      {this.unread = 0, this.lastMessage, this.lastTime});

  int unread;           // count of unread messages

  String? lastMessage;  // description of last message
  DateTime? lastTime;   // time of last message

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz id="$identifier" type=$type name="$name"'
        ' isFriend=$isFriend blocked=$isBlocked muted=$isMuted>\n'
        '\t<unread>$unread</unread>\n'
        '\t<msg>$lastMessage</msg>\n\t<time>$lastTime</time>\n</$clazz>';
  }

}

class Amanuensis implements lnc.Observer {
  factory Amanuensis() => _instance;
  static final Amanuensis _instance = Amanuensis._internal();
  Amanuensis._internal() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kMetaSaved);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  final Map<ID, List<ReliableMessage>> _incomingMessages = {};
  final Map<ID, List<InstantMessage>>  _outgoingMessages = {};

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    assert(name == NotificationNames.kMembersUpdated
        || name == NotificationNames.kDocumentUpdated
        || name == NotificationNames.kMetaSaved, 'name error: $notification');
    assert(info != null, 'user info error: $notification');
    GlobalVariable shared = GlobalVariable();
    SharedFacebook facebook = shared.facebook;
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      assert(false, 'messenger not create yet');
      return;
    }

    // 1. check conversation ID
    ID? entity = ID.parse(info!['ID']);
    if (entity == null) {
      assert(false, 'conversation ID not found');
      return;
    } else if (entity.isUser) {
      // check user
      if (await facebook.getPublicKeyForEncryption(entity) == null) {
        Log.error('user not ready yet: $entity');
        return;
      }
    } else {
      assert(entity.isGroup, 'conversation ID error: $entity');
      // check group member
      List<ID> members = await facebook.getMembers(entity);
      if (members.isEmpty) {
        Log.error('group not ready yet: $entity');
        return;
      }
      // TODO: check group members' visa.key
    }

    // 2. processing outgoing messages
    List<InstantMessage>? outgoing = _outgoingMessages.remove(entity);
    if (outgoing != null) {
      for (InstantMessage item in outgoing) {
        messenger.sendInstantMessage(item, priority: 1);
      }
    }

    // 3. processing incoming messages
    List<ReliableMessage>? incoming = _incomingMessages.remove(entity);
    if (incoming != null) {
      List<ReliableMessage>? responses;
      for (ReliableMessage item in incoming) {
        responses = await messenger.processReliableMessage(item);
        if (responses.isEmpty) {
          continue;
        }
        for (ReliableMessage res in responses) {
          messenger.sendReliableMessage(res, priority: 1);
        }
      }
    }
  }

  void suspendReliableMessage(ReliableMessage rMsg) {
    // save this message in a queue waiting sender's meta response
    ID? waiting = ID.parse(rMsg.getString('waiting'));
    if (waiting == null) {
      waiting = rMsg.group;
      waiting ??= rMsg.sender;
    } else {
      rMsg.remove('waiting');
    }
    List<ReliableMessage>? array = _incomingMessages[waiting];
    if (array == null) {
      _incomingMessages[waiting] = [rMsg];
    } else {
      array.add(rMsg);
    }
  }

  void suspendInstantMessage(InstantMessage iMsg) {
    // save this message in a queue waiting receiver's visa/meta/members response
    ID? waiting = ID.parse(iMsg.getString('waiting'));
    if (waiting == null) {
      waiting = iMsg.group;
      waiting ??= iMsg.receiver;
    } else {
      iMsg.remove('waiting');
    }
    List<InstantMessage>? array = _outgoingMessages[waiting];
    if (array == null) {
      _outgoingMessages[waiting] = [iMsg];
    } else {
      array.add(iMsg);
    }
  }

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
      if (chat.isBlocked) {
      } else if (chat.isFriend) {
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
      if (chat.isBlocked) {
      } else if (chat.isFriend) {
      } else {
        array.add(chat);
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
      for (Conversation item in array) {
        await item.reloadData();
        // TODO: get last message & unread count
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
      chat.lastTime = null;
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
  Future<ID> _cid(Envelope env) async {
    // check receiver
    ID receiver = env.receiver;
    if (receiver.isGroup) {
      // group chat, get chat box with group ID
      return receiver;
    }
    // check group
    ID? group = env.group;
    if (group != null) {
      // group chat, get chat box with group ID
      return group;
    }
    // personal chat, get chat box with contact ID
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    assert(user != null, 'current user should not be empty here');
    ID sender = env.sender;
    if (sender == user?.identifier) {
      return receiver;
    } else {
      return sender;
    }
  }

  Future<bool> clearUnread(ID cid) async {
    Conversation? chatBox = _conversationMap[cid];
    if (chatBox == null) {
      return false;
    }
    chatBox.unread = 0;
    GlobalVariable shared = GlobalVariable();
    if (await shared.database.updateConversation(chatBox)) {
      Log.debug('unread count cleared: $chatBox');
    } else {
      Log.error('failed to update conversation: $chatBox');
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
    if (await shield.isBlocked(cid)) {
      Log.warning('blocked: $cid');
      return;
    }
    Content content = iMsg.content;
    DefaultMessageBuilder mb = DefaultMessageBuilder();
    if (mb.isCommand(content)) {
      Log.debug('ignore command for conversation updating');
      return;
    }
    String last = mb.getText(content, iMsg.sender);
    if (last.isEmpty) {
      Log.warning('content text empty: $content');
      return;
    }
    DateTime? time = iMsg.time;
    Log.warning('update last message: $last for conversation: $cid');

    GlobalVariable shared = GlobalVariable();
    Conversation? chatBox = _conversationMap[cid];
    if (chatBox == null) {
      // new conversation
      chatBox = Conversation(cid, unread: 1, lastMessage: last, lastTime: time);
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
      chatBox.unread += 1;
      chatBox.lastMessage = last;
      chatBox.lastTime = time;
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
      SymmetricKey? key = await shared.mdb.getCipherKey(me, group);
      if (key != null) {
        //key.put("reused", null);
        key.remove("reused");
      }
    }
    if (content is QueryCommand) {
      // FIXME: same query command sent to different members?
      return true;
    }

    ID cid = await _cid(iMsg.envelope);
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
    ID cid = await _cid(env);
    ID sender = env.sender;  // original sender
    int sn = content.originalSerialNumber;
    String? signature = content.originalSignature;
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
    });
    return true;
  }

}
