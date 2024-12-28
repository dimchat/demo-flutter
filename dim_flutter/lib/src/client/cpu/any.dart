
import 'package:dim_client/sdk.dart';
import 'package:dim_client/group.dart';

class AnyContentProcessor extends BaseContentProcessor {
  AnyContentProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    String text;

    // File: Image, Audio, Video
    if (content is FileContent) {
      if (content is ImageContent) {
        // Image
        text = "Image received";
      } else if (content is AudioContent) {
        // Audio
        text = "Voice message received";
      } else if (content is VideoContent) {
        // Video
        text = "Movie received";
      } else {
        // other file
        text = "File received";
      }
    } else if (content is TextContent) {
      // Text
      text = "Text message received";
    } else if (content is PageContent) {
      // Web page
      text = "Web page received";
    } else if (content is NameCard) {
      // Name Card
      text = "Name card received";
    } else if (content is QuoteContent) {
      // Quote
      text = "Quote message received";
    } else if (content is MoneyContent) {
      if (content.type == ContentType.CLAIM_PAYMENT) {
        // Claim Payment
        text = "Claim payment received";
      } else if (content.type == ContentType.SPLIT_BILL) {
        // Split Bill
        text = "Split bill received";
      } else if (content.type == ContentType.LUCKY_MONEY) {
        // Lucky Money
        text = "Lucky money received";
      } else if (content is TransferContent) {
        // Transfer money
        text = "Transfer money message received";
      } else {
        // other money
        text = "Unrecognized money message";
      }
    } else {
      // Other
      return await super.processContent(content, rMsg);
    }

    var group = content.group;
    if (group != null && rMsg.containsKey('group')) {
      // the group ID is overt, normally it must be redirected by a group bot,
      // and the bot should respond the sender after delivered to any member,
      // so we don't need to response the sender here
      SharedGroupManager man = SharedGroupManager();
      List<ID> bots = await man.getAssistants(group);
      if (bots.isNotEmpty) {
        // let the group bot to do the job
        return [];
      }
    }

    // response
    return respondReceipt(text, content: content, envelope: rMsg.envelope);
  }

}
