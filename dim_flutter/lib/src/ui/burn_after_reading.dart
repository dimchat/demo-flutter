import 'package:get/get.dart';

import 'package:lnc/lnc.dart';

import '../client/shared.dart';

import '../filesys/local.dart';
import 'settings.dart';


class BurnAfterReadingItem {
  BurnAfterReadingItem(this.duration, this.description);

  final int duration;
  final String description;
}

class BurnAfterReadingDataSource {
  factory BurnAfterReadingDataSource() => _instance;
  static final BurnAfterReadingDataSource _instance = BurnAfterReadingDataSource._internal();
  BurnAfterReadingDataSource._internal();

  AppSettings? _settings;

  DateTime? _lastBurn;

  static const int kManually = 0;
  static const int kDaily = 3600 * 24;
  static const int kWeekly = 3600 * 24 * 7;
  static const int kMonthly = 3600 * 24 * 30;

  final List<BurnAfterReadingItem> _items = [
    BurnAfterReadingItem(kManually, 'Manually'),
    BurnAfterReadingItem(kMonthly, 'Monthly'),
    BurnAfterReadingItem(kWeekly, 'Weakly'),
    BurnAfterReadingItem(kDaily, 'Daily'),
  ];

  Future<void> init(AppSettings settings) async {
    _settings = settings;
  }

  Future<bool> setBurnAfterReading(int duration) async {
    bool ok = await _settings!.setValue('burn_after_reading', duration);
    assert(ok, 'failed to set burnAfterReading: $duration');
    return ok;
  }

  // seconds from now
  int getBurnAfterReading() => _settings?.getValue('burn_after_reading') ?? kManually;

  String getBurnAfterReadingDescription() {
    int duration = getBurnAfterReading();
    for (var pair in _items) {
      if (pair.duration == duration) {
        return pair.description;
      }
    }
    // not found?
    return _calculate(duration);
  }

  Future<bool> burnAll() async {
    int duration = getBurnAfterReading();
    if (duration <= 0) {
      Log.warning('manual mode');
      return false;
    } else if (duration < 60) {
      assert(false, 'burn time error: $duration');
      return false;
    }
    DateTime now = DateTime.now();
    // check last time
    DateTime? last = _lastBurn;
    if (last != null) {
      int elapsed = now.millisecondsSinceEpoch - last.millisecondsSinceEpoch;
      if (elapsed < 15000) {
        // too frequently
        Log.warning('burn next time: $elapsed');
        return false;
      }
    }
    _lastBurn = now;
    // calculate expired time
    int millis = now.millisecondsSinceEpoch - duration * 1000;
    DateTime expired = DateTime.fromMillisecondsSinceEpoch(millis);
    // 1. cleanup messages
    Log.warning('burning message before: $expired');
    GlobalVariable shared = GlobalVariable();
    bool ok = await shared.database.burnMessages(expired);
    Log.warning('burn expired messages: $ok, $expired');
    // 2. TODO: cleanup files
    LocalStorage storage = LocalStorage();
    int count = await storage.burnAll(expired);
    Log.warning('burn expired files: $count, $expired');
    return ok || count > 0;
  }

  //
  //  Sections
  //

  int getSectionCount() => 1;

  int getItemCount(int section) => _items.length;

  BurnAfterReadingItem getItem(int sec, int item) => _items[item];

}

String _calculate(int duration) {
  if (duration < _seconds) {
    // less than 2 seconds
    return 'Error'.tr;
  } else if (duration < _minutes) {
    // less than 2 minutes
    return '@several seconds'.trParams({
      'several': '$duration',
    });
  } else if (duration < _hours) {
    // less than 2 hours
    return '@several minutes'.trParams({
      'several': '${duration ~/ _minute}',
    });
  } else if (duration < _days) {
    // less than 2 days
    return '@several hours'.trParams({
      'several': '${duration ~/ _hour}',
    });
  } else if (duration < _months) {
    // less than 2 months
    return '@several days'.trParams({
      'several': '${duration ~/ _day}',
    });
  } else {
    return '@several days'.trParams({
      'several': '${duration ~/ _month}',
    });
  }
}
const int _seconds = 2;
const int _minute  = 60;
const int _minutes = 60 * 2;
const int _hour    = 3600;
const int _hours   = 3600 * 2;
const int _day     = 3600 * 24;
const int _days    = 3600 * 24 * 2;
const int _month   = 3600 * 24 * 30;
const int _months  = 3600 * 24 * 61;
