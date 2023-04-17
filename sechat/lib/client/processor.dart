import 'package:dim_client/dim_client.dart';

import '../models/conversation.dart';
import 'cpu/creator.dart';

class SharedProcessor extends ClientMessageProcessor {
  SharedProcessor(super.facebook, super.messenger);

  @override
  ContentProcessorCreator createCreator() {
    return SharedContentProcessorCreator(facebook, messenger);
  }

  @override
  Future<List<InstantMessage>> processInstantMessage(InstantMessage iMsg, ReliableMessage rMsg) async {
    List<InstantMessage> responses = await super.processInstantMessage(iMsg, rMsg);
    // save instant message
    Amanuensis clerk = Amanuensis();
    if (await clerk.saveInstantMessage(iMsg)) {} else {
      // error
      Log.error('failed to save instant message: ${iMsg.sender} -> ${iMsg.receiver}');
      return [];
    }
    return responses;
  }

}
