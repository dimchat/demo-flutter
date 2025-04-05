
import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../client/shared.dart';
import '../common/constants.dart';
import '../models/config.dart';
import 'language.dart';

/*
        translate content : {
            type : 0xCC,
            sn   : 123,

            app   : "chat.dim.translate",  // application
            mod   : "translate",           // module name
            act   : "request",             // action name (or "respond")

            tag   : 123,

            text   : "{TEXT}",  // or {TRANSLATION} in respond
            code   : "{LANG_CODE}",
            result : {
                from        : "{SOURCE_LANGUAGE}",
                to          : "{TARGET_LANGUAGE}",
                code        : "{LANG_CODE}",
                text        : "{TEXT}",        // source text
                translation : "{TRANSLATION}"  // target text
            }
        }
 */

class TranslateResult extends Dictionary {
  TranslateResult(super.dict);

  /// source language name
  String? get from => getString('from', null);

  /// target language name
  String? get to => getString('to', null);

  /// target language code
  String? get code => getString('code', null);

  /// source text
  String? get text => getString('text', null);

  /// target text
  String? get translation => getString('translation', null);

  // bool get valid => from != null && to != null && code != null && translation != null;
  bool get valid {
    if (from == null || to == null || code == null) {
      return false;
    }
    // sometimes the AI server would return translation in 'text' field
    return translation != null || text != null;
  }

}

class TranslateContent extends AppCustomizedContent {
  TranslateContent(super.dict);

  /// serial number of source message content
  int? get tag => getInt('tag', null);

  String? get text => getString('text', null);

  /// target language code
  String? get code => result?.code ?? getString('code', null);

  TranslateResult? get result {
    Map? info = this['result'];
    return info == null ? null : TranslateResult(info);
  }

  /// check translate result valid
  bool get success => result?.valid == true;

  TranslateContent.query(String text, int tag, {required String? format})
      : super.from(app: Translator.app, mod: Translator.mod, act: 'request') {
    // source text
    this['text'] = text;
    // source sn
    if (tag > 0) {
      this['tag'] = tag;
    }
    this['format'] = format;
    this['muted'] = true;
    this['hidden'] = true;
    this['code'] = _currentLanguageCode();
  }

}

String _currentLanguageCode() {
  String code = LanguageDataSource().getCurrentLanguageCode();
  if (code.isEmpty) {
    GlobalVariable shared = GlobalVariable();
    code = shared.terminal.language;
  }
  return code;
}

class Translator with Logging implements Observer {
  factory Translator() => _instance;
  static final Translator _instance = Translator._internal();
  Translator._internal() {
    var nc = NotificationCenter();
    nc.addObserver(this, NotificationNames.kTranslatorWarning);
  }

  static const String app = 'chat.dim.translate';
  static const String mod = 'translate';

  /// lang_code => text => translate
  final Map<String, Map<String, TranslateContent>> _textCache = {};
  /// lang_code => tag => translate
  final Map<String, Map<int, TranslateContent>> _tagCache = {};

  /// service bots
  ID? _fastestTranslator;
  String? _warningMessage;
  DateTime? _lastQueryTime;
  int _queryInterval = 32;

  String? get warning => _warningMessage;

  bool get ready => _fastestTranslator != null;

  bool canTranslate(Content content) => content is TextContent;

  @override
  Future<void> onReceiveNotification(Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kTranslatorWarning) {
      ID? sender = info?['sender'];
      TranslateContent? content = info?['content'];
      TranslateResult? result = content?.result;
      if (sender == null) {
        logError('translator error: $info');
      } else {
        var text = result?.translation;
        text ??= result?.text;
        _updateTranslator(sender, text);
      }
    }
  }

  void _updateTranslator(ID sender, String? text) {
    var fastest = _fastestTranslator;
    if (fastest == null) {
      fastest = sender;
    } else if (text == null) {
      logWarning('warning text not found: $sender');
      return;
    } else if (fastest != sender) {
      logWarning('fastest translator exists: $fastest, $sender');
      return;
    }
    logInfo('update fastest translator: $fastest, "$text"');
    _fastestTranslator = fastest;
    _warningMessage = text;
    // post notification
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kTranslatorReady, this, {
      // 'action': 'update',
      'translator': fastest,
    });
  }

  Future<bool> testCandidates() async {
    Config config = await Config().load();
    var bots = config.translators;
    if (bots.isEmpty) {
      return false;
    } else if (_fastestTranslator != null) {
      // TODO: what if warning message is empty
      return true;
    }
    // check last query time
    var now = DateTime.now();
    var last = _lastQueryTime;
    if (last != null && now.subtract(Duration(seconds: _queryInterval)).isBefore(last)) {
      logWarning('last query is not expired, call it after $_queryInterval seconds.');
      return false;
    } else {
      _lastQueryTime = now;
      _queryInterval <<= 1;
    }
    // query candidates
    var content = TranslateContent.query('Hi there!', 0, format: null);
    content['mod'] = 'test';
    logInfo('say hi to translators: $bots, $content');
    GlobalVariable shared = GlobalVariable();
    for (ID receiver in bots) {
      await shared.emitter.sendContent(content, receiver: receiver);
    }
    return true;
  }

  Future<bool> request(String text, int tag, {required String? format}) async {
    ID? receiver = _fastestTranslator;
    if (receiver == null) {
      logWarning('translator not found');
      return false;
    }
    var content = TranslateContent.query(text, tag, format: format);
    logInfo('sending to translator: $receiver, $content');
    GlobalVariable shared = GlobalVariable();
    await shared.emitter.sendContent(content, receiver: receiver);
    return true;
  }

  // String? translate({
  //   required String text,
  //   required int tag,  // sn
  // }) => fetch(text: text, tag: tag)?.text;

  TranslateContent? fetch(String text, int tag) {
    String code = _currentLanguageCode();
    return _textCache[code]?[text] ?? _tagCache[code]?[tag];
  }

  bool update(TranslateContent content) {
    String? code = content.code;
    if (code == null || code.isEmpty) {
      assert(false, 'translate content error: $content');
      return false;
    }
    bool ok1 = false, ok2 = false;
    // update for source text
    String? text = content.result?.text;
    if (text != null && text.isNotEmpty) {
      ok1 = _cacheText(content, text: text, code: code);
    }
    // update for source sn
    int? sn = content.tag;
    if (sn != null && sn > 0) {
      ok2 = _cacheTag(content, tag: sn, code: code);
    }
    return ok1 || ok2;
  }

  bool _cacheText(TranslateContent content, {required String text, required String code}) {
    Map<String, TranslateContent>? info = _textCache[code];
    if (info == null) {
      // insert new record
      _textCache[code] = {text: content};
      return true;
    } else if (content.success) {
      // update new result
      info[text] = content;
      return true;
    }
    // new record is not success,
    // check old record first
    TranslateContent? old = info[text];
    if (old?.success == true) {
      // old record exits and it's success
      // no need to update again
      return false;
    }
    // update as temporary record
    info[text] = content;
    return true;
  }
  bool _cacheTag(TranslateContent content, {required int tag, required String code}) {
    Map<int, TranslateContent>? info = _tagCache[code];
    if (info == null) {
      // insert new record
      _tagCache[code] = {tag: content};
      return true;
    } else if (content.success) {
      // update new result
      info[tag] = content;
      return true;
    }
    // new record is not success,
    // check old record first
    TranslateContent? old = info[tag];
    if (old?.success == true) {
      // old record exits and it's success
      // no need to update again
      return false;
    }
    // update as temporary record
    info[tag] = content;
    return true;
  }

}
