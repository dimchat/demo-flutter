
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

  // private
  String buildKey(String app, String mod, String title) {
    String key = '$app:$mod:$title';
    if (key.length > 64) {
      logWarning('trimming key: $key');
      // FIXME: use MD5 instead?
      key = key.substring(0, 65);
    }
    return key;
  }

  Future<Content?> getContent(String app, String mod, String title) async {
    String key = buildKey(app, mod, title);
    Mapper? content = await database.getAppCustomizedInfo(key, mod: mod);
    return Content.parse(content);
  }

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

  Future<bool> saveContent(Content content, {Duration? expires}) async {
    String? text = content['text'];
    if (text != null && text.length > 128) {
      String head = text.substring(0, 100);
      String tail = text.substring(105);
      text = '$head ... $tail';
    }

    String? app = content['app'];
    String? mod = content['mod'];
    String? act = content['act'];
    String? title = content['title'];
    // if (title == null || title.isEmpty) {
    //   title = content['keywords'];
    // }

    var nc = NotificationCenter();
    bool ok = false;

    if (app == null || mod == null || title == null) {
      logError('service content error: $content');
    } else if (app == 'chat.dim.search') {
      Log.info('got customized text content: $text');
      if (mod == 'users') {
        // got online users
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(app, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
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
        String key = buildKey(app, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        var lives = content['lives'];
        Log.info('got ${lives?.length} lives');
        nc.postNotification(NotificationNames.kLiveSourceUpdated, this, {
          'cmd': content,
          'lives': lives,
        });
      }
    } else if (app == 'chat.dim.sites') {
      Log.info('got customized text content: $text');
      if (mod == 'homepage') {
        // got home page
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(app, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        nc.postNotification(NotificationNames.kWebSitesUpdated, this, {
          'cmd': content,
        });
      }
    }
    // OK
    return ok;
  }

  Future<bool> clearExpiredContents() async =>
      await database.clearExpiredAppCustomizedInfo();

}
