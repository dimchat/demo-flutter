import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';


abstract class MessageTemplate {

  static String getText(Mapping content) {
    try {
      var template = content['template'];
      var replacements = content['replacements'];
      if (template is String && replacements is Map) {
        return _getTempText(template, replacements);
      }
      return Converter.getString(content['text']) ?? '';
    } catch (e, st) {
      Log.error('message error: $e, $content, $st');
      return e.toString();
    }
  }

  static String _getTempText(String template, Map replacements) {
    Log.info('template: $template');
    replacements.forEach((key, value) {
      // replace value for key
      template = replaceTemplate(template, key: key, value: value);
    });
    return template;
  }

  static String replaceTemplate(String template, {dynamic key, dynamic value}) {
    List<String>? pair = _getTempValues(template, key: key, value: value);
    if (pair == null) {
      return template;
    }
    return template.replaceAll(pair[0], pair[1]);
  }

  static List<String>? _getTempValues(String template, {dynamic key, dynamic value}) {
    String tag;
    String? sub;
    // check for plain text
    tag = '\${$key}';
    if (template.contains(tag)) {
      if (value is String) {
        sub = value;
      } else {
        sub = '$value';
      }
      return [tag, sub];
    }
    // check for base64 encode
    tag = '\${base64_encode($key)}';
    if (template.contains(tag)) {
      if (value is String) {
        sub = Base64.encode(UTF8.encode(value));
        return [tag, sub];
      } else {
        assert(false, 'base64 value error: $key -> $value');
      }
    }
    // TODO: others format?
    assert(false, 'template key not found: $key');
    return null;
  }

}
