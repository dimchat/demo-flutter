import 'package:get/get.dart';

import 'package:lnc/time.dart';

abstract class TimeUtils extends Time {

  ///  Now()
  ///
  /// @return current time
  static DateTime get currentTime => Time.currentTime;

  ///  Now() as timestamp
  ///
  /// @return current timestamp in seconds from Jan 1, 1970 UTC
  static double get currentTimestamp => Time.currentTimestamp;

  ///  Convert timestamp to date
  ///
  /// @param timestamp - seconds from Jan 1, 1970 UTC
  static DateTime? getTime(Object? timestamp) => Time.getTime(timestamp);

  ///  Convert date to timestamp
  ///
  /// @param time - DateTime object or seconds as double
  /// @return seconds from Jan 1, 1970 UTC
  static double? getTimestamp(Object? time) => Time.getTimestamp(time);

  /// readable time string
  static String getTimeString(DateTime time) {
    time = time.toLocal();
    int timestamp = time.millisecondsSinceEpoch;
    // special time
    DateTime now = currentTime;
    int midnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    int newYear = DateTime(now.year).millisecondsSinceEpoch;
    // hh:mm
    String hh = _twoDigits(time.hour);
    String mm = _twoDigits(time.minute);
    if (timestamp >= midnight) {
      // today
      if (time.hour < 12) {
        return '${'AM'.tr} $hh:$mm';
      } else {
        return '${'PM'.tr} $hh:$mm';
      }
    } else if (timestamp >= (midnight - 24 * 3600 * 1000)) {
      // yesterday
      return '${'Yesterday'.tr} $hh:$mm';
    } else if (timestamp >= (midnight - 72 * 3600 * 1000)) {
      // recently
      String weekday = _weakDayName(time.weekday);
      return '$weekday $hh:$mm';
    }
    // m-d
    String m = _twoDigits(time.month);
    String d = _twoDigits(time.day);
    if (timestamp >= newYear) {
      // this year
      return '$m-$d $hh:$mm';
    } else {
      return '${time.year}-$m-$d';
    }
  }

  /// yyyy-MM-dd HH:mm:ss
  static String getFullTimeString(DateTime time) {
    time = time.toLocal();
    String m = _twoDigits(time.month);
    String d = _twoDigits(time.day);
    String h = _twoDigits(time.hour);
    String min = _twoDigits(time.minute);
    String sec = _twoDigits(time.second);
    return '${time.year}-$m-$d $h:$min:$sec';
  }

  static String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  static String _weakDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday'.tr;
      case DateTime.tuesday:
        return 'Tuesday'.tr;
      case DateTime.wednesday:
        return 'Wednesday'.tr;
      case DateTime.thursday:
        return 'Thursday'.tr;
      case DateTime.friday:
        return 'Friday'.tr;
      case DateTime.saturday:
        return 'Saturday'.tr;
      case DateTime.sunday:
        return 'Sunday'.tr;
      default:
        assert(false, 'weekday error: $weekday');
        return '';
    }
  }
}
