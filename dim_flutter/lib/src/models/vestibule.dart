
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/constants.dart';
import '../client/facebook.dart';
import '../client/messenger.dart';
import '../client/shared.dart';

/// Message Waiting List
class Vestibule implements Observer {
  factory Vestibule() => _instance;
  static final Vestibule _instance = Vestibule._internal();
  Vestibule._internal() {
    var nc = NotificationCenter();
    nc.addObserver(this, NotificationNames.kMetaSaved);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  final Map<ID, List<ReliableMessage>> _incomingMessages = {};
  final Map<ID, List<InstantMessage>>  _outgoingMessages = {};

  @override
  Future<void> onReceiveNotification(Notification notification) async {
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
    ID? entity = ID.parse(info?['ID']);
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
      // check group
      Bulletin? bulletin = await facebook.getBulletin(entity);
      if (bulletin == null) {
        Log.error('group not ready yet: $entity');
        return;
      }
      ID? owner = await facebook.getOwner(entity);
      if (owner == null) {
        Log.error('group not ready yet: $entity');
        return;
      }
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
        await shared.emitter.sendInstantMessage(item, priority: 1);
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
          await messenger.sendReliableMessage(res, priority: 1);
        }
      }
    }
  }

  void suspendReliableMessage(ReliableMessage rMsg) {
    // save this message in a queue waiting sender's meta response
    ID? waiting = ID.parse(rMsg['waiting']);
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
    ID? waiting = ID.parse(iMsg['waiting']);
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

}
