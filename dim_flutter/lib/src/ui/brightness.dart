import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings.dart';
import 'colors.dart';


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
    // update brightness of facade
    int order = getCurrentOrder();
    _updateBrightness(order);
  }

  void _updateBrightness(int order) {
    if (order == kLight) {
      ThemeColors.setBrightness(Brightness.light);
    } else if (order == kDark) {
      ThemeColors.setBrightness(Brightness.dark);
    } else {
      ThemeColors.setBrightness(null);
    }
  }

  Future<bool> setBrightness(int order) async {
    bool ok = await _settings!.setValue('brightness', order);
    if (!ok) {
      assert(false, 'failed to set brightness: $order');
      return false;
    }
    _updateBrightness(order);
    await forceAppUpdate();
    return true;
  }

  int getCurrentOrder() => _settings?.getValue('brightness') ?? kSystem;

  String getCurrentName() => _names[getCurrentOrder()];

  //
  //  Sections
  //

  int getSectionCount() => 1;

  int getItemCount(int section) => _names.length;

  BrightnessItem getItem(int sec, int item) => BrightnessItem(item, _names[item]);

}
