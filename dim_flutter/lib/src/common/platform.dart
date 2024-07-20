import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
// import 'package:fvp/fvp.dart';

import 'package:lnc/log.dart';

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

  /// patch for SQLite
  static void patchSQLite() {
    if (_sqlitePatched) {
      return;
    }
    if (isWeb) {
      // Change default factory on the web
      databaseFactory = databaseFactoryFfiWeb;
    } else if (isWindows || isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
    }
    _sqlitePatched = true;
  }
  static bool _sqlitePatched = false;

  /// patch for Video Player
  static void patchVideoPlayer() {
    if (_videoPlayerPatched) {
      return;
    }
    if (isAndroid || isIOS || isMacOS || isWeb) {
      // Video Player support:
      // - Android SDK 16+
      // - iOS 12.0+
      // - macOS 10.14+
      // - Web Any*
    } else {
      // - Windows
      // - Linux
      // ...
      Log.info('register video player for Windows, Linux, ...');
      // TODO: open for windows
      // registerWith();
    }
    _videoPlayerPatched = true;
  }
  static bool _videoPlayerPatched = false;

}

/// TODO: patch for block colors in dark theme
///
///   file: '/Users/moky/.pub-cache/hosted/pub.flutter-io.cn/flutter_markdown-0.6.22+1/lib/src/style_sheet.dart'
///   line: 144
///
///   old:
///
///     class MarkdownStyleSheet {
///       ...
///       factory MarkdownStyleSheet.fromTheme(ThemeData theme) {
///         ...
///         blockquoteDecoration: BoxDecoration(
///           color: Colors.blue.shade100,
///           borderRadius: BorderRadius.circular(2.0),
///         ),
///
///   new:
///
///     class MarkdownStyleSheet {
///       ...
///       factory MarkdownStyleSheet.fromTheme(ThemeData theme) {
///         ...
///         blockquoteDecoration: BoxDecoration(
///           color: theme.brightness == Brightness.dark
///               ? Colors.grey.shade800
///               : Colors.blue.shade100,
///           borderRadius: BorderRadius.circular(2.0),
///         ),
