import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import '../models/amanuensis.dart';
import 'cpu/creator.dart';

class SharedProcessor extends ClientMessageProcessor {
  SharedProcessor(super.facebook, super.messenger);

  final FrequencyChecker<ID> _groupQueries = FrequencyChecker(600);

  @override
  ContentProcessorCreator createCreator() {
    return SharedContentProcessorCreator(facebook, messenger);
  }

  @override
  Future<List<SecureMessage>> processSecureMessage(SecureMessage sMsg, ReliableMessage rMsg) async {
    try {
      return await super.processSecureMessage(sMsg, rMsg);
    } catch (e) {
      // RangeError: Value not in range: 3
      Log.error('failed to process message: ${rMsg.sender} -> ${rMsg.receiver}: $e');
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
      Log.error('failed to save instant message: ${iMsg.sender} -> ${iMsg.receiver}');
      return [];
    }
    return responses;
  }

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    if (content is! Command) {
      ID? group = content.group;
      if (group != null) {
        Document? bulletin = await facebook.getDocument(group, '*');
        if (bulletin == null && _groupQueries.isExpired(group)) {
          ID sender = rMsg.sender;
          Log.info('querying group: $group, $sender');
          Content content = DocumentCommand.query(group, null);
          messenger.sendContent(content, sender: null, receiver: sender, priority: 1);
        }
      }
    }
    return await super.processContent(content, rMsg);
  }

}
