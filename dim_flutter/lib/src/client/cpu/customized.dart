
import 'package:dim_client/client.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../../common/constants.dart';
import '../../ui/translation.dart';

class AppCustomizedContentProcessor extends CustomizedContentProcessor with Logging {
  AppCustomizedContentProcessor(super.facebook, super.messenger);

  @override
  List<Content>? filter(String app, CustomizedContent content, ReliableMessage rMsg) {
    if (app == Translator.app) {
      // OK
      return null;
    }
    return super.filter(app, content, rMsg);
  }

  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) async {
    String app = content.application;
    String mod = content.module;
    if (/*app != Translator.app && */mod != Translator.mod/* && act != 'respond'*/) {
      String text = 'Content not support.';
      return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
        'template': 'Customized content (app: \${app}, mod: \${mod}, act: \${act}) not support yet!',
        'replacements': {
          'app': app,
          'mod': mod,
          'act': act,
        }
      });
    }
    // parse & cache translate content
    TranslateContent tr = TranslateContent(content.toMap());
    if (/*tr.application == Translator.app && */tr.module == Translator.mod) {
      if (tr.action == 'respond') {
        bool ok = Translator().update(tr);
        logInfo('update translation: $ok, $tr');
        if (ok) {
          // post notification
          var nc = NotificationCenter();
          nc.postNotification(NotificationNames.kTranslateUpdated, this, {
            // 'action': 'update',
            'content': tr,
          });
        }
      }
    }
    return [];
  }

}
