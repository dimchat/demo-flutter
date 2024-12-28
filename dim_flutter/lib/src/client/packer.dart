
import 'package:dim_client/sdk.dart';
import 'package:dim_client/client.dart';

import '../models/vestibule.dart';
import 'shared.dart';

class SharedPacker extends ClientMessagePacker {
  SharedPacker(super.facebook, super.messenger);

  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    // make sure visa.key exists before encrypting message

    //
    //  Check FileContent
    //  ~~~~~~~~~~~~~~~~~
    //  You'd better upload file data before packing message.
    //
    Content content = iMsg.content;
    if (content is FileContent) {
      // encrypt & upload file data before send out
      if (content.data != null/* && content.url == null*/) {
        ID sender = iMsg.sender;
        ID receiver = iMsg.receiver;
        ID? group = iMsg.group;
        logWarning('You should upload file data before calling sendInstantMessage'
            ': $sender -> $receiver ($group)');
        SymmetricKey? password = SymmetricKey.generate(SymmetricKey.AES);
        // SymmetricKey? password = await messenger?.getEncryptKey(iMsg);
        if (password == null) {
          assert(false, 'failed to generate AES key: $sender => $receiver, $group');
          // return null;
        } else {
          // 2. call emitter to encrypt & upload file data
          GlobalVariable shared = GlobalVariable();
          bool ok = await shared.emitter.uploadFileData(content, password: password, sender: sender);
          if (!ok) {
            Map<String, String> error = {
              'message': 'failed to upload file data',
              'user': sender.toString(),
            };
            await suspendInstantMessage(iMsg, error);
            // return null;
          }
        }
      }
      // make sure that the file data has been uploaded to CDN correctly.
      if (content.data != null/* || content.url == null*/) {
        logError('file content error: $content');
        return null;
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
  Future<void> suspendInstantMessage(InstantMessage iMsg, Map info) async {
    iMsg['error'] = info;
    Vestibule clerk = Vestibule();
    clerk.suspendInstantMessage(iMsg);
  }

  @override
  Future<void> suspendReliableMessage(ReliableMessage rMsg, Map info) async {
    rMsg['error'] = info;
    Vestibule clerk = Vestibule();
    clerk.suspendReliableMessage(rMsg);
  }

}
