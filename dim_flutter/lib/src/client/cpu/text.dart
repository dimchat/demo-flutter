
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../../common/constants.dart';
import '../../common/dbi/app.dart';
import '../shared.dart';


class TextContentProcessor extends BaseContentProcessor {
  TextContentProcessor(super.facebook, super.messenger) {
    GlobalVariable shared = GlobalVariable();
    _serviceContentHandler = ServiceContentHandler(shared.database);
  }

  late final ServiceContentHandler _serviceContentHandler;

  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    assert(content is TextContent, 'text content error: $content');
    if (_serviceContentHandler.checkContent(content)) {
      await _serviceContentHandler.saveContent(content);
    }
    // OK
    return [];
  }

}

class ServiceContentHandler with Logging {
  ServiceContentHandler(this.database);

  final AppCustomizedInfoDBI database;

  bool checkContent(Content content) {
    String? app = content['app'];
    String? mod = content['mod'];
    String? act = content['act'];
    if (app == null || mod == null || act == null) {
      return false;
    } else if (app == 'chat.dim.search') {
      // service: online users
      return mod == 'users';
    } else if (app == 'chat.dim.tvbox') {
      // service: live streams
      return mod == 'lives';
    } else if (app == 'chat.dim.sites') {
      // service: home page
      return mod == 'homepage';
    } else {
      logWarning('unknown content: $app, $mod, $act');
      return false;
    }
  }

  Future<bool> saveContent(Content content) async {
    String? text = content['text'];
    if (text != null && text.length > 128) {
      String head = text.substring(0, 100);
      String tail = text.substring(105);
      text = '$head ... $tail';
    }

    var nc = NotificationCenter();
    bool ok = false;

    String? app = content['app'];
    String? mod = content['mod'];
    String? act = content['act'];
    String? title = content['title'];
    if (app == 'chat.dim.search') {
      Log.info('got customized text content: $text');
      if (mod == 'users') {
        // got online users
        assert(act == 'respond', 'customized text content error: $text');
        ok = await database.saveAppCustomizedContent(content, '$app:$mod:$title');
        var users = content['users'];
        Log.info('got ${users?.length} users');
        nc.postNotification(NotificationNames.kActiveUsersUpdated, this, {
          'cmd': content,
          'users': users,
        });
      }
    } else if (app == 'chat.dim.tvbox') {
      Log.info('got customized text content: $text');
      if (mod == 'lives') {
        // got live streams
        assert(act == 'respond', 'customized text content error: $text');
        ok = await database.saveAppCustomizedContent(content, '$app:$mod:$title');
        var lives = content['lives'];
        Log.info('got ${lives?.length} lives');
        nc.postNotification(NotificationNames.kLiveSourceUpdated, this, {
          'cmd': content,
          'lives': lives,
        });
        return true;
      }
    } else if (app == 'chat.dim.sites') {
      Log.info('got customized text content: $text');
      if (mod == 'homepage') {
        // got home page
        assert(act == 'respond', 'customized text content error: $text');
        ok = await database.saveAppCustomizedContent(content, '$app:$mod:$title');
        nc.postNotification(NotificationNames.kWebSitesUpdated, this, {
          'cmd': content,
        });
        return true;
      }
    }
    // OK
    return ok;
  }

}
