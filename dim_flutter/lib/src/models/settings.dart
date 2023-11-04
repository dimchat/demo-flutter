import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/styles.dart';


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
  bright.init(settings);
  // 2. init language
  var language = LanguageDataSource();
  language.init(settings);
}

//
//  Brightness
//

class BrightnessItem {
  BrightnessItem(this.order, this.name);

  final int order;
  final String name;
}

class BrightnessDataSource {
  factory BrightnessDataSource() => _instance;
  static final BrightnessDataSource _instance = BrightnessDataSource._internal();
  BrightnessDataSource._internal();

  AppSettings? _settings;

  final List<String> _names = [
    'System',
    'Light',
    'Dark',
  ];

  void init(AppSettings settings) async {
    _settings = settings;
    // update brightness of facade
    int order = getCurrentOrder();
    _updateBrightness(order);
  }

  void _updateBrightness(int order) {
    if (order == 1) {
      Facade.setBrightness(Brightness.light);
    } else if (order == 2) {
      Facade.setBrightness(Brightness.dark);
    } else {
      Facade.setBrightness(null);
    }
  }

  Future<bool> setBrightness(int order) async {
    bool ok = await _settings!.setValue('brightness', order);
    if (!ok) {
      assert(false, 'failed to set brightness: $order');
      return false;
    }
    _updateBrightness(order);
    return true;
  }

  int getCurrentOrder() => _settings?.getValue('brightness') ?? 0;

  String getCurrentName() => _names[getCurrentOrder()];

  //
  //  Sections
  //

  int getSectionCount() => 1;

  int getItemCount(int section) => _names.length;

  BrightnessItem getItem(int sec, int item) => BrightnessItem(item, _names[item]);

}

//
//  Language
//

class LanguageItem {
  LanguageItem(this.order, this.name);

  final int order;
  final String name;
}

class LanguageDataSource {
  factory LanguageDataSource() => _instance;
  static final LanguageDataSource _instance = LanguageDataSource._internal();
  LanguageDataSource._internal();

  AppSettings? _settings;

  final List<String> _names = [
    'System',
    'English',
  ];

  void init(AppSettings settings) async {
    _settings = settings;
  }

  Future<bool> setLanguage(int order) async {
    bool ok = await _settings!.setValue('language', order);
    if (!ok) {
      assert(false, 'failed to set language: $order');
      return false;
    }
    // TODO: update facade
    return true;
  }

  int getCurrentOrder() => _settings?.getValue('language') ?? 0;

  String getCurrentName() => _names[getCurrentOrder()];

  //
  //  Sections
  //

  int getSectionCount() => 1;

  int getItemCount(int section) => _names.length;

  LanguageItem getItem(int sec, int item) => LanguageItem(item, _names[item]);

}
