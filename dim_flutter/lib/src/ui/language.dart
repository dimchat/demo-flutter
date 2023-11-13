import 'dart:ui';

import 'package:get/get.dart';

import 'settings.dart';
import 'intl_en_us.dart';
import 'intl_es_es.dart';
import 'intl_fr_fr.dart';
import 'intl_de_de.dart';
import 'intl_it_it.dart';
import 'intl_ja_jp.dart';
import 'intl_ko_kr.dart';
import 'intl_ru_ru.dart';
import 'intl_th_th.dart';
import 'intl_vi_vn.dart';
import 'intl_zh_cn.dart';
import 'intl_zh_tw.dart';


class LanguageItem {
  LanguageItem(this.code, this.name);

  final String code;
  final String name;
}

class LanguageDataSource {
  factory LanguageDataSource() => _instance;
  static final LanguageDataSource _instance = LanguageDataSource._internal();
  LanguageDataSource._internal();

  AppSettings? _settings;

  final List<LanguageItem> _items = [
    LanguageItem('', 'System'),
    LanguageItem('en_US', 'English'),
    LanguageItem('es_ES', 'Español'),
    LanguageItem('fr_FR', 'Français'),
    LanguageItem('de_DE', 'Deutsch'),
    LanguageItem('it_IT', 'Italiano'),
    LanguageItem('ja_JP', '日本語'),
    LanguageItem('ko_KR', '한국인'),
    LanguageItem('ru_RU', 'Русский'),
    LanguageItem('th_TH', 'ภาษาไทย'),
    LanguageItem('vi_VN', 'Tiếng Việt'),
    LanguageItem('zh_CN', '简体中文'),
    LanguageItem('zh_TW', '繁體中文'),
  ];

  Future<void> init(AppSettings settings) async {
    _settings = settings;
    // update language
    String code = getCurrentLanguageCode();
    _updateLanguage(code);
  }

  void _updateLanguage(String code) {
    List<String> pair = code.split('_');
    Locale? locale;
    if (pair.length > 1) {
      assert(pair.first.isNotEmpty, 'language code error: $code');
      locale = Locale(pair.first, pair.last);
    } else if (pair.length == 1 && pair.first.isNotEmpty) {
      locale = Locale(pair.first);
    } else {
      locale = Get.deviceLocale;
    }
    if (locale != null) {
      Get.updateLocale(locale);
    }
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

    'en': intlEnUs,
    'en_US': intlEnUs,
    'en_GB': intlEnUs,

    'es': intlEsEs,
    'es_ES': intlEsEs,

    'fr': intlFrFr,
    'fr_FR': intlFrFr,

    'de': intlDeDe,
    'de_DE': intlDeDe,

    'it': intlItIt,
    'it_IT': intlItIt,

    'ja': intlJaJp,
    'ja_JP': intlJaJp,

    'ko': intlKoKr,
    'ko_KR': intlKoKr,

    'ru': intlRuRu,
    'ru_RU': intlRuRu,

    'th': intlThTh,
    'th_TH': intlThTh,

    'vi': intlViVN,
    'vi_VN': intlViVN,

    'zh': intlZhCn,
    'zh_CN': intlZhCn,
    'zh_TW': intlZhTw,

  };

}
