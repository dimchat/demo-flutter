import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

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
      if (content.containsKey('data')/* && content.containsKey('URL')*/) {
        ID sender = iMsg.sender;
        ID receiver = iMsg.receiver;
        SymmetricKey? key = await messenger.getCipherKey(sender, receiver,
            generate: true);
        if (key == null) {
          assert(false, 'failed to get msg key for: $sender -> $receiver');
        } else {
          // call emitter to encrypt & upload file data before send out
          GlobalVariable shared = GlobalVariable();
          await shared.emitter.sendFileContentMessage(iMsg, key);
        }
        return null;
      }
    }

    SecureMessage? sMsg;
    try {
      sMsg = await super.encryptMessage(iMsg);
    } on RangeError catch (e) {
      Log.error('failed to encrypt message: $e');
      return null;
    }
    ID receiver = iMsg.receiver;
    if (receiver.isGroup) {
      // reuse group message keys
      SymmetricKey? key = await messenger.getCipherKey(iMsg.sender, receiver);
      key?['reused'] = true;
    }
    // TODO: reuse personal message key?

    return sMsg;
  }

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg = await super.decryptMessage(sMsg);
    if (iMsg != null) {
      Content content = iMsg.content;
      if (content is FileContent && content.containsKey('URL')) {
        // now received file content with remote data,
        // which must be encrypted before upload to CDN;
        // so keep the password here for decrypting after downloaded.
        await _keepPassword(content, iMsg);
      }
    }
    return iMsg;
  }

  Future<void> _keepPassword(FileContent content, InstantMessage iMsg) async {
    if (content.containsKey('data')) {
      // this content was sent with plain file data, no need to decrypt
      Log.warning('file data exists: $content');
      return;
    }
    DecryptKey? key = content.password;
    if (key != null) {
      // this content was sent with a decrypt key, no need to be replaced
      Log.warning('password already exists: $content');
      return;
    }
    ID sender = iMsg.sender;
    ID receiver = iMsg.receiver;
    key = await messenger.getCipherKey(sender, receiver);
    assert(key != null, 'failed to get password: $sender -> $receiver');
    // keep password to decrypt data after downloaded
    content.password = key;
  }

}
