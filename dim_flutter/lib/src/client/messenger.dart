import 'dart:typed_data';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/client.dart';

import '../models/shield.dart';
import '../models/vestibule.dart';
import '../network/velocity.dart';

import 'compat/visa.dart';
import 'shared.dart';


class SharedMessenger extends ClientMessenger {
  SharedMessenger(super.session, super.facebook, super.mdb);

  @override
  Future<Content?> deserializeContent(Uint8List data, SymmetricKey password,
      SecureMessage sMsg) async {
    Content? content = await super.deserializeContent(data, password, sMsg);
    if (content is Command) {
      // get client IP from handshake response
      if (content is HandshakeCommand) {
        var remote = content['remote_address'];
        logWarning('socket address: $remote in $content, msg: ${sMsg.sender} -> ${sMsg.receiver}');
      }
    }
    return content;
  }

  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    Shield shield = Shield();
    if (await shield.isBlocked(rMsg.sender, group: rMsg.group)) {
      logWarning('contact is blocked: ${rMsg.sender}, group: ${rMsg.group}');
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
      if (receiver.isUser && receiver != Station.ANY) {
        String? name = receiver.name;
        ID? aid;
        if (name != null) {
          aid = ClientFacebook.ans?.identifier(name);
        }
        if (aid == null) {
          logInfo('broadcast message with receiver: $receiver');
          // TODO: wrap it by ForwardContent
        } else {
          logInfo('convert receiver: $receiver => $aid');
          receiver = aid;
        }
      }
    }
    return await super.sendContent(content, sender: sender, receiver: receiver, priority: priority);
  }

  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    ReliableMessage? rMsg;
    try {
      rMsg = await super.sendInstantMessage(iMsg, priority: priority);
    } catch (e, st) {
      logError('failed to send message to: ${iMsg.receiver}, error: $e');
      logDebug('failed to send message to: ${iMsg.receiver}, error: $e, $st');
      return null;
    }
    if (rMsg != null) {
      // keep signature for checking traces
      iMsg['signature'] = rMsg.getString('signature');
    }
    return rMsg;
  }

  @override
  Future<bool> updateVisa() async {
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'current user not found');
      return false;
    }
    //
    //  0. get sign key for current user
    //
    SignKey? sKey = await facebook.getPrivateKeyForVisaSignature(user.identifier);
    if (sKey == null) {
      assert(false, 'private key not found: $user');
      return false;
    }
    //
    //  1. get visa document for current user
    //
    Visa? visa = await user.localVisa;
    if (visa == null) {
      // get any visa
      visa = await user.visa;
      if (visa == null) {
        // FIXME: query from station or create a new one?
        assert(false, 'user error: $user');
        return false;
      }
    }
    //
    //  2. clone for signing
    //
    Visa? clone = visa.clone();
    if (clone == null) {
      logError('failed to clone visa: $visa');
      return false;
    }
    assert(clone.publicKey != null, 'visa error: $clone');
    Uint8List? sig = clone.sign(sKey);
    if (sig == null) {
      assert(false, 'failed to sign visa: $clone, $user');
      return false;
    }
    //
    //  3. save the new visa document
    //
    var archivist = facebook.archivist;
    bool? ok = await archivist?.saveDocument(clone, user.identifier);
    assert(ok == true, 'failed to save document: $clone');
    logWarning('visa updated: $ok, $clone');
    return ok == true;
  }

  @override
  Future<void> handshakeSuccess() async {
    // 1. broadcast current documents after handshake success
    try {
      await super.handshakeSuccess();
    } catch (e, st) {
      logError('failed to broadcast document: $e, $st');
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
    } catch (e, st) {
      logError('failed to broadcast login command: $e, $st');
    }
    // 3. broadcast block/mute list
    try {
      Shield shield = Shield();
      await shield.broadcastBlockList();
      await shield.broadcastMuteList();
    } catch (e, st) {
      logError('failed to broadcast block/mute list: $e, $st');
    }
    // 4. report station speeds to master after tested speeds

    // 5. resume messages
    Vestibule clerk = Vestibule();
    await clerk.resumeMessages(user.identifier);
  }

  Future<void> reportSpeeds(List<VelocityMeter> meters, ID provider) async {
    if (meters.isEmpty) {
      logWarning('meters empty');
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
