import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'nav.dart';
import 'settings.dart';


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

  static const int kSystem = 0;
  static const int kLight = 1;
  static const int kDark = 2;

  final List<String> _names = [
    'System',
    'Light',
    'Dark',
  ];

  Future<void> init(AppSettings settings) async {
    _settings = settings;
  }

  Brightness get current => isDarkMode ? Brightness.dark : Brightness.light;

  Future<bool> setBrightness(int order) async {
    // update setting
    bool ok = await _settings!.setValue('brightness', order);
    assert(ok, 'failed to set brightness: $order');
    // refresh app
    await forceAppUpdate();
    return ok;
  }

  bool get isDarkMode {
    int order = getCurrentBrightnessOrder();
    if (order == kLight) {
      return false;
    } else if (order == kDark) {
      return true;
    } else {
      return Get.isPlatformDarkMode;
    }
  }

  ThemeMode get themeMode {
    int order = getCurrentBrightnessOrder();
    if (order == kLight) {
      return ThemeMode.light;
    } else if (order == kDark) {
      return ThemeMode.dark;
    } else {
      return ThemeMode.system;
    }
  }

  int getCurrentBrightnessOrder() => _settings?.getValue('brightness') ?? kSystem;

  String getCurrentBrightnessName() => _names[getCurrentBrightnessOrder()];

  //
  //  Sections
  //

  int getSectionCount() => 1;

  int getItemCount(int section) => _names.length;

  BrightnessItem getItem(int sec, int item) => BrightnessItem(item, _names[item]);

}
