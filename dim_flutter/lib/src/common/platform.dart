import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DevicePlatform {

  static bool get isDesktop => !isWeb && (isWindows || isLinux || isMacOS);

  static bool get isMobile => isAndroid || isIOS;

  static bool get isWeb => kIsWeb;

  static bool get isWindows => !kIsWeb && Platform.isWindows;

  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static bool get isFuchsia => !kIsWeb && Platform.isFuchsia;

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static String get localeName => kIsWeb ? 'en_US' : Platform.localeName;

  static String get operatingSystem => kIsWeb ? 'Web Browser' : Platform.operatingSystem;

  /// patch for sqlite
  static void patchSQLite() {
    if (_sqlitePatched) {
      return;
    }
    if (DevicePlatform.isWeb) {
      // Change default factory on the web
      databaseFactory = databaseFactoryFfiWeb;
    // } else if (DevicePlatform.isWindows || DevicePlatform.isLinux) {
    //   // Initialize FFI
    //   sqfliteFfiInit();
    //   // Change the default factory
    //   databaseFactory = databaseFactoryFfi;
    }
    _sqlitePatched = true;
  }
  static bool _sqlitePatched = false;

}
