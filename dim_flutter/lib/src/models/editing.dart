import 'chat.dart';

class SharedEditingText {
  factory SharedEditingText() => _instance;
  static final SharedEditingText _instance = SharedEditingText._internal();
  SharedEditingText._internal();

  final Map<String, String> _values = {};

  String? getText({required String key}) =>
      _values[key];

  void setText(String value, {required String key}) =>
      _values[key] = value;

  String? getConversationEditingText(Conversation info) =>
      getText(key: info.identifier.toString());

  void setConversationEditingText(String text, Conversation info) =>
      setText(text, key: info.identifier.toString());

  String? getSearchingText() =>
      getText(key: 'Searching');

  void setSearchingText(String text) =>
      setText(text, key: 'Searching');

}
