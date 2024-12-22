
import 'package:dim_client/sdk.dart';
import 'package:dim_client/client.dart';

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
