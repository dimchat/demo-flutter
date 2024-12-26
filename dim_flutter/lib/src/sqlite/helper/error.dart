
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

abstract interface class DBErrorPatch {

  static InstantMessage rebuildMessage(String json) {
    var info = _getPartiallyInfo(json);
    Log.warning('building partially message: $info');
    return InstantMessage.parse(info)!;
  }

}

Map _getPartiallyInfo(String json) {
  String? sender = _getJsonStringValue(json, key: 'sender');
  String? receiver = _getJsonStringValue(json, key: 'receiver');
  String? group = _getJsonStringValue(json, key: 'group');
  double? time = _getJsonNumberValue(json, key: 'time');

  double? type = _getJsonNumberValue(json, key: 'type');
  double? sn = _getJsonNumberValue(json, key: 'sn');
  String? text = _getJsonStringValue(json, key: 'text');
  return {
    'sender': sender ?? ID.ANYONE.toString(),
    'receiver': receiver ?? ID.ANYONE.toString(),
    'group': group,
    'time': time,
    'content': {
      'type': type,
      'sn': sn,
      'time': time,
      'group': group,
      'text': text ?? '_(error message)_',
    }
  };
}

String? _getJsonStringValue(String json, {required String key}) {
  String tag = '"$key":"';
  int start = json.indexOf(tag);
  if (start < 0) {
    Log.warning('json key not found: $key');
    return null;
  }
  String value;
  start += tag.length;
  int end = json.indexOf('"', start);
  if (end > start) {
    value = json.substring(start, end);
  } else {
    value = json.substring(start);
  }
  return value;
}

double? _getJsonNumberValue(String json, {required String key}) {
  String tag = '"$key":';
  int start = json.indexOf(tag);
  if (start < 0) {
    Log.warning('json key not found: $key');
    return null;
  }
  String value;
  start += tag.length;
  int end = json.indexOf(',', start);
  if (end > start) {
    value = json.substring(start, end);
  } else {
    value = json.substring(start);
  }
  if (value.startsWith('"')) {
    Log.warning('json key value error: $key, $value');
    return null;
  }
  return Converter.getDouble(value, null);
}
