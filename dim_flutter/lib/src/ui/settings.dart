import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'burn_after_reading.dart';
import 'brightness.dart';
import 'language.dart';


/// Shared Preferences
class AppSettings {
  factory AppSettings() => _instance;
  static final AppSettings _instance = AppSettings._internal();
  AppSettings._internal();

  SharedPreferences? _preferences;

  Future<SharedPreferences> load() async {
    SharedPreferences? sp = _preferences;
    if (sp == null) {
      _preferences = sp = await SharedPreferences.getInstance();
    }
    return sp;
  }

  T getValue<T>(String key) => _preferences?.get(key) as T;

  Future<bool> setValue<T>(String key, T value) async {
    bool? ok;
    switch (T) {
      case bool:
        ok = await _preferences?.setBool(key, value as bool);
      case int:
        ok = await _preferences?.setInt(key, value as int);
      case double:
        ok = await _preferences?.setDouble(key, value as double);
      case String:
        ok = await _preferences?.setString(key, value as String);
      case List:
        ok = await _preferences?.setStringList(key, value as List<String>);
      default:
        assert(false, 'type error: $T, key: $key');
        return false;
    }
    return ok == true;
  }

  Future<bool> removeValue(String key) async =>
      await _preferences?.remove(key) ?? false;

// Future<bool> clear() async => await _preferences.clear();
//
// Future<void> reload() async => await _preferences.reload();

}


Future<void> initFacade() async {
  // 0. load settings
  AppSettings settings = AppSettings();
  await settings.load();
  // 1. init brightness
  var bright = BrightnessDataSource();
  await bright.init(settings);
  // 2. init language
  var language = LanguageDataSource();
  await language.init(settings);
  // 3. init 'burn after reading'
  var burn = BurnAfterReadingDataSource();
  await burn.init(settings);
}

void launchApp(Widget home) => runApp(GetMaterialApp(
  // debugShowCheckedModeBanner: false,
  theme: BrightnessDataSource.light,
  darkTheme: BrightnessDataSource.dark,
  themeMode: BrightnessDataSource().themeMode,
  home: home,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
  ],
  translations: LanguageDataSource.translations,
  // locale: const Locale('zh', 'CN'),
  fallbackLocale: const Locale('en', 'US'),
));

Future<void> forceAppUpdate() async => await Get.forceAppUpdate();

Future<void> openPage(Widget pop) async => await Get.to(pop);

void closePage() => Get.back();
