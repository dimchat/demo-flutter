import 'dart:io';
import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../models/shield.dart';
import '../network/velocity.dart';

import '../ui/language.dart';
import 'shared.dart';

class SharedMessenger extends ClientMessenger {
  SharedMessenger(super.session, super.facebook, super.mdb);

  @override
  Future<Uint8List?> encryptKey(Uint8List key, ID receiver, InstantMessage iMsg) async {
    try {
      return await super.encryptKey(key, receiver, iMsg);
    } catch (e) {
      // FIXME:
      Log.error('failed to encrypt key for receiver: $receiver, $e');
      return null;
    }
  }

  @override
  Future<Content?> deserializeContent(Uint8List data, SymmetricKey password,
      SecureMessage sMsg) async {
    Content? content = await super.deserializeContent(data, password, sMsg);
    if (content is Command) {
      // get client IP from handshake response
      if (content is HandshakeCommand) {
        var remote = content['remote_address'];
        Log.warning('socket address: $remote');
      }
    }
    return content;
  }

  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    Shield shield = Shield();
    if (await shield.isBlocked(rMsg.sender, group: rMsg.group)) {
      Log.warning('contact is blocked: ${rMsg.sender}, group: ${rMsg.group}');
      // TODO: upload blocked-list to current station?
      return null;
    }
    return await super.verifyMessage(rMsg);
  }

  @override
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content,
      {required ID? sender, required ID receiver, int priority = 0}) async {
    if (receiver.isBroadcast) {
      // check whether need to wrap this message
      if (receiver.isUser && receiver != Station.kAny) {
        String? name = receiver.name;
        ID? aid;
        if (name != null) {
          aid = ClientFacebook.ans?.identifier(name);
        }
        if (aid == null) {
          Log.info('broadcast message with receiver: $receiver');
          // TODO: wrap it by ForwardContent
        } else {
          Log.info('convert receiver: $receiver => $aid');
          receiver = aid;
        }
      }
    }
    return super.sendContent(content, sender: sender, receiver: receiver, priority: priority);
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    ReliableMessage? rMsg;
    try {
      rMsg = await super.sendInstantMessage(iMsg, priority: priority);
    } catch (e) {
      Log.error('failed to send message to: ${iMsg.receiver}, $e');
      // assert(false, '$e');
      return null;
    }
    if (rMsg != null) {
      // keep signature for checking traces
      iMsg['signature'] = rMsg.getString('signature', null);
    }
    return rMsg;
  }

  @override
  Future<void> handshake(String? sessionKey) async {
    if (sessionKey == null || sessionKey.isEmpty) {
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
        // set app id
        doc.setProperty('app_id', 'chat.dim.tarsier');
        // set locale for language
        String locale = Platform.localeName;
        doc.setProperty('locale', locale);
        // set customized language
        LanguageDataSource lds = LanguageDataSource();
        String language = lds.getCurrentLanguageCode();
        doc.setProperty('language', language);
        // sign it
        Uint8List? sig = doc.sign(sKey);
        assert(sig != null, 'failed to sign visa: $doc');
        bool ok = await facebook.saveDocument(doc);
        assert(ok, 'failed to save document: $doc');
        Log.info('visa updated: $doc');
      }
    }
    await super.handshake(sessionKey);
  }

  @override
  Future<void> handshakeSuccess() async {
    // 1. broadcast current documents after handshake success
    try {
      await super.handshakeSuccess();
    } catch (e) {
      Log.error('failed to broadcast document: $e');
    }
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'should not happen');
      return;
    }
    // 2. broadcast login command with current station info
    try {
      await broadcastLogin(user.identifier, shared.terminal.userAgent);
    } catch (e) {
      Log.error('failed to broadcast login command: $e');
    }
    // 3. broadcast block/mute list
    try {
      Shield shield = Shield();
      await shield.broadcastBlockList();
      await shield.broadcastMuteList();
    } catch (e) {
      Log.error('failed to broadcast block/mute list: $e');
    }
    // 4. report station speeds to master after tested speeds
  }

  Future<void> reportSpeeds(List<VelocityMeter> meters, ID provider) async {
    if (meters.isEmpty) {
      Log.warning('meters empty');
      return;
    }
    List stations = [];
    for (VelocityMeter item in meters) {
      stations.add({
        'host': item.host,
        'port': item.port,
        'response_time': item.responseTime,
        'test_date': item.info.testTime?.toString(),
        'socket_address': item.socketAddress,
      });
    }
    ID master = ID.parse('monitor@anywhere')!;
    Content content = CustomizedContent.create(
      app: 'chat.dim.monitor',
      mod: 'speeds',
      act: 'post',
    );
    content['provider'] = provider.toString();
    content['stations'] = stations;
    await sendContent(content, sender: null, receiver: master, priority: 1);
  }

}
