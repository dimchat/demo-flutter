import 'dart:typed_data';

import 'package:dim_client/dim_client.dart';

import 'compatible.dart';

class SharedMessenger extends ClientMessenger {
  SharedMessenger(super.session, super.facebook, super.mdb);

  @override
  void suspendInstantMessage(InstantMessage iMsg, Map info) {
    // TODO: implement suspendInstantMessage
  }

  @override
  void suspendReliableMessage(ReliableMessage rMsg, Map info) {
    // TODO: implement suspendReliableMessage
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

}
