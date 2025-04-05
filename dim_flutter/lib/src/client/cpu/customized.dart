
import 'package:dim_client/client.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../../common/constants.dart';
import '../../ui/translation.dart';

class AppCustomizedContentProcessor extends CustomizedContentProcessor with Logging {
  AppCustomizedContentProcessor(super.facebook, super.messenger);

  final _translateHandler = _TranslateHandler();

  @override
  List<Content>? filter(String app, CustomizedContent content, ReliableMessage rMsg) {
    if (app == Translator.app) {
      // OK
      return null;
    }
    return super.filter(app, content, rMsg);
  }

  @override
  CustomizedContentHandler? fetch(String mod, CustomizedContent content, ReliableMessage rMsg) {
    if (mod == Translator.mod) {
      return _translateHandler;
    } else if (mod == 'test') {
      return _translateHandler;
    }
    return this;
  }

}

class _TranslateHandler with Logging implements CustomizedContentHandler {

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
