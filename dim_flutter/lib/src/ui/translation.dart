
import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../client/shared.dart';
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

  bool get valid => from != null && to != null && code != null && translation != null;

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

  TranslateContent.query(String text, int tag)
      : super.from(app: Translation.app, mod: Translation.mod, act: 'request') {
    String code = LanguageDataSource().getCurrentLanguageCode();
    this['text'] = text;
    if (code.isNotEmpty) {
      this['code'] = code;
    }
    if (tag > 0) {
      this['tag'] = tag;
    }
  }

}

class Translation with Logging {
  factory Translation() => _instance;
  static final Translation _instance = Translation._internal();
  Translation._internal();

  static const String app = 'chat.dim.translate';
  static const String mod = 'translate';

  /// lang_code => text => translate
  final Map<String, Map<String, TranslateContent>> _textCache = {};
  /// lang_code => tag => translate
  final Map<String, Map<int, TranslateContent>> _tagCache = {};

  Future<bool> query(String text, int tag) async {
    List<ID> candidates = await Config().translators;
    if (candidates.isEmpty) {
      logWarning('translator not found');
      return false;
    }
    // TODO: check for fastest bot
    ID receiver = candidates.first;
    var content = TranslateContent.query(text, tag);
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
    String code = LanguageDataSource().getCurrentLanguageCode();
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
