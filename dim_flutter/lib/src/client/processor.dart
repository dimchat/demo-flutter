import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import '../models/amanuensis.dart';
import 'cpu/creator.dart';

class SharedProcessor extends ClientMessageProcessor with Logging {
  SharedProcessor(super.facebook, super.messenger);

  @override
  ContentProcessorCreator createCreator() {
    return SharedContentProcessorCreator(facebook!, messenger!);
  }

  @override
  Future<List<SecureMessage>> processSecureMessage(SecureMessage sMsg, ReliableMessage rMsg) async {
    try {
      return await super.processSecureMessage(sMsg, rMsg);
    } catch (e, st) {
      // RangeError: Value not in range: 3
      logInfo('error message signature: ${rMsg['debug-sig']}');
      logError('failed to process message: ${rMsg.sender} -> ${rMsg.receiver}: $e, st');
      // assert(false, 'failed to process message: ${rMsg.sender} -> ${rMsg.receiver}: $e');
      return [];
    }
  }

  @override
  Future<List<InstantMessage>> processInstantMessage(InstantMessage iMsg, ReliableMessage rMsg) async {
    List<InstantMessage> responses = await super.processInstantMessage(iMsg, rMsg);
    // save instant message
    Amanuensis clerk = Amanuensis();
    if (await clerk.saveInstantMessage(iMsg)) {} else {
      // error
      logError('failed to save instant message: ${iMsg.sender} -> ${iMsg.receiver}');
      return [];
    }
    return responses;
  }

}
