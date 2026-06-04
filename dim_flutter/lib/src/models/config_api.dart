import 'package:dim_client/ok.dart';
import 'package:pnf/enigma.dart';

/// Upload API
/// ~~~~~~~~~~
///
/// JSON format:
///   {
///     "upload": {
///       "avatar": [
///         {
///           "url": "http://tfs.dim.chat/upload/{ID}/avatar?md5={MD5}&salt={SALT}",
///           "enigma": "250110"
///         }
///       ],
///       "file": [
///         {
///           "url": "http://tfs.dim.chat/upload/{ID}/file?md5={MD5}&salt={SALT}",
///           "enigma": "250110"
///         }
///       ]
///     }
///   }

class UploadServer with ClassNameMixIn {
  UploadServer(this.url, this.keys);

  final String url;
  final List<String> keys;

  String get className => getClassName('UploadServer');

  @override
  String toString() {
    String clazz = className;
    return '<$clazz url="$url">\r\n'
        '    keys: $keys\r\n'
        '</$clazz>';
  }

  static List<EnigmaItem> parseEnigmaItems(Iterable secrets) {
    List<EnigmaItem> items = [];
    EnigmaItem? enigma;
    for (var sec in secrets) {
      if (sec is Map) {
        enigma = EnigmaItem.parse(sec);
      } else if (sec is! String) {
        assert(false, 'enigma item error: $sec');
        continue;
      } else if (sec.length < 8) {
        assert(sec.isEmpty, 'enigma item error: $sec');
        continue;
      } else {
        // default: HEX encoding
        enigma = EnigmaItem.parse({
          "index": sec.substring(0, 6),
          "secret": 'hex,$sec',
        });
      }
      if (enigma == null || enigma.isEmpty) {
        assert(false, 'enigma item error: $sec');
        continue;
      }
      items.add(enigma);
    }
    return items;
  }

  //
  //  Conveniences
  //

  static List<UploadServer> convert(Iterable array) {
    List<UploadServer> items = [];
    UploadServer? server;
    for (var item in array) {
      server = parse(item);
      if (server == null) {
        continue;
      }
      items.add(server);
    }
    return items;
  }

  //
  //  Factory method
  //

  static UploadServer? parse(Object? info) {
    if (info == null) {
      return null;
    } else if (info is UploadServer) {
      return info;
    }
    String url;
    List<String> keys;
    if (info is Map) {
      var pair = _fetchFromMap(info);
      if (pair == null) {
        return null;
      }
      url = pair.first;
      keys = pair.second;
    } else if (info is String) {
      url = _APIUtils.getUrlString(info) ?? '';
      if (url.isEmpty) {
        assert(false, 'upload API error: $info');
        return null;
      }
      keys = _APIUtils.fetchEnigmaKeys(url);
    } else {
      return null;
    }
    assert(keys.isNotEmpty, 'enigma keys not found: $info');
    return UploadServer(url, keys);
  }

  static Pair<String, List<String>>? _fetchFromMap(Map item) {
    String? url = _APIUtils.getUrlString(item['url'] ?? item['URL']);
    if (url == null) {
      assert(false, 'upload API not found: $item');
      return null;
    }
    List<String> keys;
    String? enigma = item['enigma'];
    if (enigma is String) {
      keys = enigma.split(',');
    } else {
      keys = _APIUtils.fetchEnigmaKeys(url);
    }
    return Pair(url, keys) ;
  }

}

abstract class _APIUtils {

  //
  //  URL: "https://tfs.dim.chat/{ID}/upload?md5={MD5}&salt={SALT}&enigma={ENIGMA}"
  //

  static String? getUrlString(Object? url) =>
      (url is String && url.contains('://')) ? url : null;

  /// Get enigma keys for URL
  static List<String> fetchEnigmaKeys(String url) {
    // get enigma from URL
    String? enigma = Template.getQueryParam(url, 'enigma');
    if (enigma == null || enigma == '{ENIGMA}') {
      return [];
    }
    return enigma.split(',');
  }

}
