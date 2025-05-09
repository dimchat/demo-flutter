import 'dart:ui';

import 'package:get/get.dart';

import 'settings.dart';
import 'intl_af_za.dart';   // Afrikaans-South Africa
import 'intl_ar_msa.dart';  // Arabic-Modern Standard Arabic
import 'intl_bn_bd.dart';   // Bengali-Bangladesh
import 'intl_de_de.dart';   // German-Germany
import 'intl_en_us.dart';
import 'intl_es_es.dart';   // Spanish-Spain
import 'intl_fr_fr.dart';   // French-France
import 'intl_hi_in.dart';   // Hindi-North India
import 'intl_id_id.dart';   // Indonesian-Indonesia
import 'intl_it_it.dart';   // Italian-Italy
import 'intl_ja_jp.dart';   // Japanese-Japan
import 'intl_ko_kr.dart';   // Korean-Korea
import 'intl_ms_my.dart';   // Malaysian-Malaysia
import 'intl_nl_nl.dart';   // Dutch-Netherlands
import 'intl_pt_pt.dart';   // Portuguese-Portugal
import 'intl_ru_ru.dart';   // Russian-Russia
import 'intl_th_th.dart';   // Thai-Thailand
import 'intl_tr_tr.dart';   // Turkish-Turkey
import 'intl_vi_vn.dart';   // Vietnamese-Vietnam
import 'intl_zh_cn.dart';
import 'intl_zh_tw.dart';


class LanguageItem {
  LanguageItem(this.code, this.name, this.desc);

  final String code;
  final String name;
  final String? desc;
}

class LanguageDataSource {
  factory LanguageDataSource() => _instance;
  static final LanguageDataSource _instance = LanguageDataSource._internal();
  LanguageDataSource._internal();

  AppSettings? _settings;

  final List<LanguageItem> _items = [
    LanguageItem('', 'System', null),

    LanguageItem('en_US', langEnglish, null),
    LanguageItem('es_ES', langSpanish, 'Spanish'),
    LanguageItem('fr_FR', langFrench, 'French'),
    LanguageItem('de_DE', langGerman, 'German'),
    LanguageItem('it_IT', langItalian, 'Italian'),
    LanguageItem('nl_NL', langDutch, 'Dutch'),
    LanguageItem('pt_PT', langPortuguese, 'Portuguese'),
    LanguageItem('ru_RU', langRussian, 'Russian'),
    LanguageItem('ar', langArabic, 'Arabic'),
    LanguageItem('af_ZA', langAfrikaans, 'Afrikaans'),
    LanguageItem('tr_TR', langTurkish, 'Turkish'),

    LanguageItem('hi_IN', langHindi, 'Hindi'),
    LanguageItem('bn_BD', langBengali, 'Bengali'),
    LanguageItem('ja_JP', langJapanese, 'Japanese'),
    LanguageItem('ko_KR', langKorean, 'Korean'),
    LanguageItem('ms_MY', langMalaysian, 'Malay'),
    LanguageItem('th_TH', langThai, 'Thai'),
    LanguageItem('id_ID', langIndonesian, 'Indonesian'),
    LanguageItem('vi_VN', langVietnamese, 'Vietnamese'),
    LanguageItem('zh_CN', langChinese, 'Chinese'),
    LanguageItem('zh_TW', langChineseTraditional, 'Chinese'),
  ]..sort((a, b) {
    String as = a.desc ?? '';
    String bs = b.desc ?? '';
    return as.compareTo(bs);
  });

  Future<void> init(AppSettings settings) async {
    _settings = settings;
    // update language
    String code = getCurrentLanguageCode();
    _updateLanguage(code);
  }

  void _updateLanguage(String code) {
    Locale? locale = parseLocale(code);
    if (locale == null) {
      locale = Get.deviceLocale;
      if (locale == null) {
        // assert(false, 'failed to get device locale');
        return;
      }
      locale = _patchLocale(locale);
    }
    // update language setting
    Get.updateLocale(locale);
  }

  Future<bool> setLanguage(String code) async {
    bool ok = await _settings!.setValue('language', code);
    assert(ok, 'failed to set language: $code');
    _updateLanguage(code);
    // await forceAppUpdate();
    return ok;
  }

  String getCurrentLanguageCode() {
    var code = _settings?.getValue('language');
    if (code is String) {
      return code;
    }
    // assert(false, 'language code error: $code');
    return '';
  }

  String getCurrentLanguageName() {
    String code = getCurrentLanguageCode();
    for (var item in _items) {
      if (item.code == code) {
        return item.name;
      }
    }
    // assert(false, 'language not support: $code');
    return '';
  }

  //
  //  Sections
  //

  int getSectionCount() => 1;

  int getItemCount(int section) => _items.length;

  LanguageItem getItem(int sec, int item) => _items[item];

  //
  //
  //
  static Translations get translations => _Translations();

}

class _Translations extends Translations {

  @override
  Map<String, Map<String, String>> get keys => {

    'af': intlAfZa,
    'af_ZA': intlAfZa,  // Afrikaans-South Africa

    'ar': intlAr,  // Arabic-Modern Standard Arabic

    'bn': intlBnBd,
    'bn_BD': intlBnBd,  // Bengali-Bangladesh

    'de': intlDeDe,
    'de_DE': intlDeDe,  // German-Germany

    'en': intlEnUs,
    'en_US': intlEnUs,
    'en_GB': intlEnUs,

    'es': intlEsEs,
    'es_ES': intlEsEs,  // Spanish-Spain

    'fr': intlFrFr,
    'fr_FR': intlFrFr,  // French-France

    'hi': intlHiIn,
    'hi_IN': intlHiIn,  // Hindi-North India

    'id': intlIdId,
    'id_ID': intlIdId,  // Indonesian-Indonesia

    'it': intlItIt,
    'it_IT': intlItIt,  // Italian-Italy

    'ja': intlJaJp,
    'ja_JP': intlJaJp,  // Japanese-Japan

    'ko': intlKoKr,
    'ko_KR': intlKoKr,  // Korean-Korea

    'ms': intlMsMy,
    'ms_MY': intlMsMy,  // Malaysian-Malaysia

    'nl': intlNlNl,
    'nl_NL': intlNlNl,  // Dutch-Netherlands

    'pt': intlPtPt,
    'pt_PT': intlPtPt,  // Portuguese-Portugal

    'ru': intlRuRu,
    'ru_RU': intlRuRu,  // Russian-Russia

    'th': intlThTh,
    'th_TH': intlThTh,  // Thai-Thailand

    'tr': intlTrTr,
    'tr_TR': intlTrTr,  // Turkish-Turkey

    'vi': intlViVN,
    'vi_VN': intlViVN,  // Vietnamese-Vietnam

    'zh': intlZhCn,
    'zh_CN': intlZhCn,
    'zh_TW': intlZhTw,

  };

}


LanguageItem? getLanguageItem(String? code) {
  Locale? locale = parseLocale(code);
  if (locale == null) {
    return null;
  }
  // remove script code
  String? languageCode = locale.languageCode;
  String? countryCode = locale.countryCode;
  if (countryCode == null || countryCode.isEmpty) {
    code = languageCode;
  } else {
    code = '${languageCode}_$countryCode';
  }
  // check language items
  LanguageItem? candidate;
  List<String> pair;
  var lds = LanguageDataSource();
  for (LanguageItem item in lds._items) {
    if (item.code == code) {
      // exactly
      return item;
    }
    pair = item.code.split('_');
    if (pair.first == languageCode) {
      // language code matched, but
      // country code not matched
      candidate = item;
    }
  }
  return candidate;
}


Locale? parseLocale(String? code) {
  if (code == null || code.isEmpty) {
    return null;
  }
  List<String> pair = code.split('_');
  String languageCode = pair.first;
  assert(languageCode.isNotEmpty, 'language code error: $code');
  if (pair.length == 1) {
    return Locale(languageCode);
  }
  String countryCode = pair.last;
  assert(countryCode.isNotEmpty, 'country code error: $code');
  if (pair.length == 2) {
    return Locale(languageCode, countryCode);
  }
  String scriptCode = pair[1];
  assert(scriptCode.isNotEmpty, 'script code error: $code');
  return _patchLocale(Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,)
  );
}

Locale _patchLocale(Locale locale) {
  // patch for Chinese (Traditional)
  var code = locale.scriptCode?.toLowerCase();
  if (code == 'hans') {
    // zh_Hans_XX
    return const Locale('zh', 'CN');
  } else if (code == 'hant') {
    // zh_Hant_XX
    return const Locale('zh', 'TW');
  }
  return locale;
}
