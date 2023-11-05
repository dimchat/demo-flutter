import 'settings.dart';


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

  Future<void> init(AppSettings settings) async {
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
