import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../models/vestibule.dart';
import 'shared.dart';

class SharedPacker extends ClientMessagePacker {
  SharedPacker(super.facebook, super.messenger);

  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    // make sure visa.key exists before encrypting message
    Content content = iMsg.content;
    if (content is FileContent) {
      if (content.data != null/* && content.url == null*/) {
        // call emitter to encrypt & upload file data before send out
        GlobalVariable shared = GlobalVariable();
        SymmetricKey? password = await shared.messenger?.getEncryptKey(iMsg);
        if (password == null) {
          assert(false, 'failed to get encrypt key: '
              '${iMsg.sender} => ${iMsg.receiver}, ${iMsg['group']}');
        } else {
          await shared.emitter.uploadFileData(content, password: password, sender: iMsg.sender);
        }
      }
    }

    // the intermediate node(s) can only get the message's signature,
    // but cannot know the 'sn' because it cannot decrypt the content,
    // this is usually not a problem;
    // but sometimes we want to respond a receipt with original sn,
    // so I suggest to expose 'sn' here.
    iMsg['sn'] = content.sn;

    // check receiver & encrypt
    return await super.encryptMessage(iMsg);
  }

  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg;
    try {
      iMsg = await super.decryptMessage(sMsg);
    } catch (e, st) {
      String errMsg = e.toString();
      if (errMsg.contains('failed to decrypt message key')) {
        // Exception from 'SecureMessagePacker::decrypt(sMsg, receiver)'
        Log.warning('decrypt message error: $e, $st');
        // visa.key changed?
        // push my newest visa to the sender
      } else if (errMsg.contains('receiver error')) {
        // Exception from 'MessagePacker::decryptMessage(sMsg)'
        Log.error('decrypt message error: $e, $st');
        // not for you?
        // just ignore it
        return null;
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

  // protected
  Future<bool> pushVisa(ID contact) async {
    GlobalVariable shared = GlobalVariable();
    ClientArchivist archivist = shared.archivist;
    if (!archivist.isDocumentResponseExpired(contact, false)) {
      // response not expired yet
      Log.debug('visa response not expired yet: $contact');
      return false;
    }
    Log.info('push visa to: $contact');
    User? user = await facebook?.currentUser;
    Visa? visa = await user?.visa;
    if (visa == null || !visa.isValid) {
      // FIXME: user visa not found?
      assert(false, 'user visa error: $user');
      return false;
    }
    ID me = user!.identifier;
    DocumentCommand command = DocumentCommand.response(me, null, visa);
    CommonMessenger transceiver = messenger as CommonMessenger;
    transceiver.sendContent(command, sender: me, receiver: contact, priority: 1);
    return true;
  }

  // protected
  Future<InstantMessage?> getFailedMessage(SecureMessage sMsg) async {
    ID sender = sMsg.sender;
    ID? group = sMsg.group;
    int? type = sMsg.type;
    if (type == ContentType.kCommand || type == ContentType.kHistory) {
      Log.warning('ignore message unable to decrypt (type=$type) from "$sender"');
      return null;
    }
    // create text content
    Content content = TextContent.create('Failed to decrypt message.');
    content.addAll({
      'template': 'Failed to decrypt message (type=\${type}) from "\${sender}".',
      'replacements': {
        'type': type,
        'sender': sender.toString(),
        'group': group?.toString(),
      }
    });
    if (group != null) {
      content.group = group;
    }
    // pack instant message
    Map info = sMsg.copyMap(false);
    info.remove('data');
    info['content'] = content.toMap();
    return InstantMessage.parse(info);
  }

  @override
  void suspendInstantMessage(InstantMessage iMsg, Map info) {
    iMsg['error'] = info;
    Vestibule clerk = Vestibule();
    clerk.suspendInstantMessage(iMsg);
  }

  @override
  void suspendReliableMessage(ReliableMessage rMsg, Map info) {
    rMsg['error'] = info;
    Vestibule clerk = Vestibule();
    clerk.suspendReliableMessage(rMsg);
  }

}
