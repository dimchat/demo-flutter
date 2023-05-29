import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../models/conversation.dart';
import 'compatible.dart';
import 'shared.dart';

class SharedMessenger extends ClientMessenger {
  SharedMessenger(super.session, super.facebook, super.mdb);

  @override
  void suspendInstantMessage(InstantMessage iMsg, Map info) {
    Amanuensis clerk = Amanuensis();
    clerk.suspendInstantMessage(iMsg);
  }

  @override
  void suspendReliableMessage(ReliableMessage rMsg, Map info) {
    Amanuensis clerk = Amanuensis();
    clerk.suspendReliableMessage(rMsg);
  }

  @override
  Future<Uint8List> serializeContent(Content content,
      SymmetricKey password, InstantMessage iMsg) async {
    if (content is Command) {
      content = Compatible.fixCommand(content);
    }
    return await super.serializeContent(content, password, iMsg);
  }

  @override
  Future<Content?> deserializeContent(Uint8List data, SymmetricKey password,
      SecureMessage sMsg) async {
    Content? content = await super.deserializeContent(data, password, sMsg);
    if (content is Command) {
      content = Compatible.fixCommand(content);
    }
    return content;
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    ReliableMessage? rMsg;
    try {
      rMsg = await super.sendInstantMessage(iMsg, priority: priority);
    } catch (e) {
      Log.error('failed to send message to: ${iMsg.receiver}');
      assert(false, '$e');
      return null;
    }
    if (rMsg != null) {
      // keep signature for checking traces
      iMsg['signature'] = rMsg.getString('signature');
    }
    return rMsg;
  }

  @override
  Future<void> handshake(String? sessionKey) async {
    if (sessionKey == null) {
      // first handshake, update visa document first
      User? user = await facebook.currentUser;
      if (user == null) {
        assert(false, 'current user not found');
        return;
      }
      SignKey? sKey = await facebook.getPrivateKeyForVisaSignature(user.identifier);
      if (sKey == null) {
        assert(false, 'private key not found: $user');
        return;
      }
      Visa? doc = await user.visa;
      if (doc == null) {
        // FIXME: query from station?
        assert(false, 'user error: $user');
      } else {
        // touch visa to update time
        var app = doc.getProperty('app');
        app ??= 'chat.dim.sechat';
        doc.setProperty('app', app);
        Uint8List? sig = doc.sign(sKey);
        assert(sig != null, 'failed to sign visa: $doc');
        bool ok = await facebook.saveDocument(doc);
        assert(ok, 'failed to save document: $doc');
      }
    }
    await super.handshake(sessionKey);
  }

  @override
  Future<void> handshakeSuccess() async {
    try {
      await super.handshakeSuccess();
    } catch (e) {
      Log.error('failed to broadcast document: $e');
    }
    // // 1. broadcast current documents after handshake success
    // await broadcastDocument();
    // 2. broadcast login command with current station info
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'should not happen');
    } else {
      await broadcastLogin(user.identifier, shared.terminal.userAgent);
    }
  }

}
