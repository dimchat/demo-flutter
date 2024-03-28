import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'brightness.dart';
import 'burn_after_reading.dart';
import 'language.dart';
import 'settings.dart';


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


Future<void> showPage({required BuildContext context, required WidgetBuilder builder}) async {
  // await showCupertinoDialog(context: context, builder: builder);
  Get.to(builder(context));
}


void closePage<T extends Object?>(BuildContext context, [ T? result ]) {
  // Navigator.pop(context, result);
  Get.back();
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
