import 'package:shared_preferences/shared_preferences.dart';


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
