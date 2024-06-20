import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';

import '../../common/constants.dart';


class TextContentProcessor extends BaseContentProcessor {
  TextContentProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is TextContent, 'text content error: $content');
    var nc = NotificationCenter();

    String? app = content['app'];
    String? mod = content['mod'];
    String? act = content['act'];
    if (app == 'chat.dim.tvbox') {
      Log.info('got customized text content: $content');
      if (mod == 'lives' && act == 'respond') {
        var lives = content['lives'];
        Log.info('got ${lives?.length} lives');
        nc.postNotification(NotificationNames.kLiveSourceUpdated, this, {
          'cmd': content,
          'lives': lives,
        });
      }
    }

    return [];
  }

}
