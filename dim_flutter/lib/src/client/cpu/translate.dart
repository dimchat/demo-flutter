
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../../common/constants.dart';
import '../../ui/translation.dart';


class TranslateContentHandler with Logging implements CustomizedContentHandler {

  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) async {
    // parse & cache translate content
    TranslateContent tr = TranslateContent(content.toMap());
    if (tr.action != 'respond') {
      logError('translate content error: $content, $sender');
      return [];
    }
    bool ok = Translator().update(tr);
    if (!ok) {
      logWarning('failed to update translate content: $content, $sender');
      return [];
    }
    // post notification
    var nc = NotificationCenter();
    if (tr.module == Translator.mod) {
      nc.postNotification(NotificationNames.kTranslateUpdated, this, {
        // 'action': 'update',
        'content': tr,
      });
    } else if (tr.module == 'test') {
      nc.postNotification(NotificationNames.kTranslatorWarning, this, {
        // 'action': 'update',
        'content': tr,
        'sender': sender,
      });
    } else {
      logError('translate content error: $content, $sender');
    }
    return [];
  }

}
