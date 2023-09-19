import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';

import '../models/amanuensis.dart';
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
        await shared.emitter.sendFileContentMessage(iMsg, key!);
      }
    }
    // check receiver & encrypt
    return await super.encryptMessage(iMsg);
  }

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg = await super.decryptMessage(sMsg);
    if (iMsg != null) {
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
    Amanuensis clerk = Amanuensis();
    clerk.suspendInstantMessage(iMsg);
  }

  @override
  void suspendReliableMessage(ReliableMessage rMsg, Map info) {
    Amanuensis clerk = Amanuensis();
    clerk.suspendReliableMessage(rMsg);
  }

}
