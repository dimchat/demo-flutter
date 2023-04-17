import 'package:dim_client/dim_client.dart';

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
    } else {
      // Other
      return await super.processContent(content, rMsg);
    }

    var group = content.group;
    if (group != null) {
      // DON'T response group message for disturb reason
      return [];
    }

    // response
    ReceiptCommand receipt = ReceiptCommand.create(text, rMsg);
    //receipt.put("signature", signature);
    return [receipt];
  }

}
