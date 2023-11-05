import 'dart:ui';

import 'package:get/get.dart';

import 'settings.dart';
import 'intl_en_us.dart';
import 'intl_zh_cn.dart';


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
    LanguageItem('zh_CN', '简体中文'),
  ];

  Future<void> init(AppSettings settings) async {
    _settings = settings;
    // update language
    String code = getCurrentCode();
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
    if (!ok) {
      assert(false, 'failed to set language: $code');
      return false;
    }
    _updateLanguage(code);
    // await forceAppUpdate();
    return true;
  }

  String getCurrentCode() {
    var code = _settings?.getValue('language');
    if (code is String) {
      return code;
    }
    // assert(false, 'language code error: $code');
    return '';
  }

  String getCurrentName() {
    String code = getCurrentCode();
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
    'zh': intlZhCn,
    'zh_CN': intlZhCn,
  };

}
