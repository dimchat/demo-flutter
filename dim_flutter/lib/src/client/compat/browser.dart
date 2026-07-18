
import 'package:device_info_plus/device_info_plus.dart';


extension BrowserVersionExtension on WebBrowserInfo {

  String? get browserVersion => _extractBrowserVersion(userAgent);

}

/*

    | Browser | User Agent Fragment | Version         |
    | ------- | ------------------- | --------------- |
    | Edge    | "Edg/128.0.2739.42" | "128.0.2739.42" |
    | Opera   | "OPR/113.0.5230.62" | "113.0.5230.62" |
    | Chrome  | "Chrome/128.0.0.0"  | "128.0.0.0"     |
    | Safari  | "Version/17.6"      | "17.6"          |
    | Firefox | "Firefox/129.0.1"   | "129.0.1"       |
    | ID      | "rv:11.0"           | "11.0"          |

 */

final List<RegExp> _browserVersionRegList = [
  RegExp(r'Edg/(\d+(?:\.\d+)*)'),            // Edge
  RegExp(r'SamsungBrowser/(\d+(?:\.\d+)*)'), // Samsung
  RegExp(r'OPR/(\d+(?:\.\d+)*)'),            // Opera
  RegExp(r'Chrome/(\d+(?:\.\d+)*)'),         // Chrome / Chromium
  RegExp(r'Version/(\d+(?:\.\d+)*)'),        // Safari
  RegExp(r'Firefox/(\d+(?:\.\d+)*)'),        // Firefox
  RegExp(r'rv:(\d+(?:\.\d+)*)'),             // IE Trident
];

String? _extractBrowserVersion(String? ua) {
  if (ua == null) {
    return null;
  }
  ua = ua.trim();
  if (ua.isEmpty) {
    return null;
  }
  for (var reg in _browserVersionRegList) {
    var match = reg.firstMatch(ua);
    if (match != null) {
      return match.group(1)!;
    }
  }
  return null;
}
