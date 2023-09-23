import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../models/vestibule.dart';
import 'compatible.dart';
import 'shared.dart';

class SharedPacker extends ClientMessagePacker {
  SharedPacker(super.facebook, super.messenger);

  @override
  Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async {
    Compatible.fixMetaAttachment(rMsg);
    return await super.serializeMessage(rMsg);
  }

  @override
  Future<ReliableMessage?> deserializeMessage(Uint8List data) async {
    ReliableMessage? rMsg = await super.deserializeMessage(data);
    if (rMsg != null) {
      Compatible.fixMetaAttachment(rMsg);
    }
    return rMsg;
  }

  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    // make sure visa.key exists before encrypting message
    Content content = iMsg.content;
    if (content is FileContent) {
      if (content.data != null/* && content.url == null*/) {
        SymmetricKey? key = await messenger?.getEncryptKey(iMsg);
        assert(key != null, 'failed to get msg key: '
            '${iMsg.sender} => ${iMsg.receiver}, ${iMsg['group']}');
        // call emitter to encrypt & upload file data before send out
        GlobalVariable shared = GlobalVariable();
        await shared.emitter.sendFileContent(iMsg, key!);
      }
    }
    // check receiver & encrypt
    return await super.encryptMessage(iMsg);
  }

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg;
    try {
      iMsg = await super.decryptMessage(sMsg);
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('failed to decrypt message key')) {
        // visa.key changed?
      } else {
        rethrow;
      }
    }
    if (iMsg == null) {
      // failed to decrypt message, visa.key changed?
      // 1. push new visa document to this message sender
      pushVisa(sMsg.sender);
      // 2. build 'failed' message
      iMsg = await getFailedMessage(sMsg);
    } else {
      Content content = iMsg.content;
      if (content is FileContent) {
        if (content.password == null && content.url != null) {
          // now received file content with remote data,
          // which must be encrypted before upload to CDN;
          // so keep the password here for decrypting after downloaded.
          SymmetricKey? key = await messenger?.getDecryptKey(sMsg);
          assert(key != null, 'failed to get msg key: '
              '${sMsg.sender} => ${sMsg.receiver}, ${sMsg['group']}');
          // keep password to decrypt data after downloaded
          content.password = key;
        }
      }
    }
    return iMsg;
  }

  @override
  void suspendInstantMessage(InstantMessage iMsg, Map info) {
    Vestibule clerk = Vestibule();
    clerk.suspendInstantMessage(iMsg);
  }

  @override
  void suspendReliableMessage(ReliableMessage rMsg, Map info) {
    Vestibule clerk = Vestibule();
    clerk.suspendReliableMessage(rMsg);
  }

  /*  Situations:
                      +-------------+-------------+-------------+-------------+
                      |  receiver   |  receiver   |  receiver   |  receiver   |
                      |     is      |     is      |     is      |     is      |
                      |             |             |  broadcast  |  broadcast  |
                      |    user     |    group    |    user     |    group    |
        +-------------+-------------+-------------+-------------+-------------+
        |             |      A      |             |             |             |
        |             +-------------+-------------+-------------+-------------+
        |    group    |             |      B      |             |             |
        |     is      |-------------+-------------+-------------+-------------+
        |    null     |             |             |      C      |             |
        |             +-------------+-------------+-------------+-------------+
        |             |             |             |             |      D      |
        +-------------+-------------+-------------+-------------+-------------+
        |             |      E      |             |             |             |
        |             +-------------+-------------+-------------+-------------+
        |    group    |             |             |             |             |
        |     is      |-------------+-------------+-------------+-------------+
        |  broadcast  |             |             |      F      |             |
        |             +-------------+-------------+-------------+-------------+
        |             |             |             |             |      G      |
        +-------------+-------------+-------------+-------------+-------------+
        |             |      H      |             |             |             |
        |             +-------------+-------------+-------------+-------------+
        |    group    |             |      J      |             |             |
        |     is      |-------------+-------------+-------------+-------------+
        |    normal   |             |             |      K      |             |
        |             +-------------+-------------+-------------+-------------+
        |             |             |             |             |             |
        +-------------+-------------+-------------+-------------+-------------+
   */
  @override
  Future<bool> checkReceiverInReliableMessage(ReliableMessage sMsg) async {
    ID receiver = sMsg.receiver;
    // check group
    ID? group = ID.parse(sMsg['group']);
    if (group == null && receiver.isGroup) {
      /// Transform:
      ///     (B) => (J)
      ///     (D) => (G)
      group = receiver;
    }
    if (group == null || group.isBroadcast) {
      /// A, C - personal message (or hidden group message)
      //      the packer will call the facebook to select a user from local
      //      for this receiver, if no user matched (private key not found),
      //      this message will be ignored;
      /// E, F, G - broadcast group message
      //      broadcast message is not encrypted, so it can be read by anyone.
      return true;
    }
    /// H, J, K - group message
    //      check for received group message
    List<ID> members = await getMembers(group);
    if (members.isNotEmpty) {
      // group is ready
      return true;
    }
    Log.error('group not ready: $group');
    // group not ready, suspend message for waiting members
    Map<String, String> error = {
      'message': 'group not ready',
      'group': group.toString(),
    };
    suspendReliableMessage(sMsg, error);  // rMsg.put("error", error);
    return false;
  }

  @override
  Future<List<ID>> getMembers(ID group) async {
    Facebook barrack = facebook!;
    CommonMessenger transceiver = messenger as CommonMessenger;
    Document? doc = await barrack.getDocument(group, '*');
    if (doc == null) {
      // group not ready, try to query document for it
      if (await transceiver.queryDocument(group)) {
        Log.info('querying document for group: $group');
      }
      return [];
    }
    List<ID> members = await barrack.getMembers(group);
    if (members.isEmpty) {
      // group not ready, try to query members for it
      if (await transceiver.queryMembers(group)) {
        Log.info('querying members for group: $group');
      }
    }
    return members;
  }

}
