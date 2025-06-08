
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
      await _serviceContentHandler.saveContent(content, rMsg.sender);
    }
    // OK
    return [];
  }

}

class ServiceContentHandler with Logging {
  ServiceContentHandler(this.database);

  final AppCustomizedInfoDBI database;

  // private
  String buildKey(ID sender, String mod, String title) {
    String address = sender.address.toString();
    if (address.length > 16) {
      address = address.substring(address.length - 16);
    }
    if (title.length > 32) {
      var data = UTF8.encode(title);
      data = MD5.digest(data);
      title = Hex.encode(data);
    }
    String key = '$address:$mod:$title';
    if (key.length > 64) {
      logWarning('trimming key: $key');
      // FIXME: use MD5 instead?
      key = key.substring(0, 65);
    }
    return key;
  }

  Future<Content?> getContent(ID sender, String mod, String title) async {
    String key = buildKey(sender, mod, title);
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
    } else if (app == 'chat.dim.video') {
      // service: video playlist
      return mod == 'playlist' || mod == 'season';
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

  Future<bool> saveContent(Content content, ID sender, {Duration? expires}) async {
    String? text = content['text'];
    if (text != null && text.length > 128) {
      String head = text.substring(0, 100);
      String tail = text.substring(105);
      text = '$head ... $tail';
    }

    String? app = content['app'];
    String? mod = content['mod'];
    String? act = content['act'];

    var nc = NotificationCenter();
    bool ok = false;

    if (app == null || mod == null) {
      logError('service content error: $content');
    }
    else if (app == 'chat.dim.search')
    {
      String title = content['title'] ?? '';
      logInfo('got customized text content: $title, $text');
      if (mod == 'users' && title.isNotEmpty) {
        // got online users
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(sender, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        var users = content['users'];
        logInfo('got ${users?.length} users');
        nc.postNotification(NotificationNames.kActiveUsersUpdated, this, {
          'cmd': content,
          'users': users,
        });
      }
    }
    else if (app == 'chat.dim.video')
    {
      Map? season = content['season'];
      String page = season?['page'] ?? '';
      String title = content['title'] ?? '';
      // logInfo('got customized text content: $text');
      if (mod == 'playlist' && title.isNotEmpty) {
        // got video playlist
        assert(act == 'respond', 'customized content error: $text');
        String key = buildKey(sender, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        var playlist = content['playlist'];
        logInfo('got ${playlist?.length} videos in playlist');
        nc.postNotification(NotificationNames.kPlaylistUpdated, this, {
          'cmd': content,
          'playlist': playlist,
        });
      } else if (mod == 'season' && page.isNotEmpty) {
        // got video season
        assert(act == 'respond', 'customized content error: $text');
        String key = buildKey(sender, mod, page);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        nc.postNotification(NotificationNames.kVideoItemUpdated, this, {
          'cmd': content,
          'season': season,
        });
      }
    }
    else if (app == 'chat.dim.tvbox')
    {
      String title = content['title'] ?? '';
      logInfo('got customized text content: $title, $text');
      if (mod == 'lives' && title.isNotEmpty) {
        // got live streams
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(sender, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        var lives = content['lives'];
        logInfo('got ${lives?.length} lives');
        nc.postNotification(NotificationNames.kLiveSourceUpdated, this, {
          'cmd': content,
          'lives': lives,
        });
      }
    }
    else if (app == 'chat.dim.sites')
    {
      String title = content['title'] ?? '';
      logInfo('got customized text content: $title, $text');
      if (mod == 'homepage' && title.isNotEmpty) {
        // got home page
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(sender, mod, title);
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
