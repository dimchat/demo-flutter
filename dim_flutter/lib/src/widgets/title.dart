import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart' as lnc;

import '../common/constants.dart';
import '../client/shared.dart';
import '../network/station_speed.dart';
import '../ui/styles.dart';


class StatedTitleView extends StatefulWidget {
  const StatedTitleView(this.getTitle, {required this.style, super.key});

  final String Function() getTitle;
  final TextStyle style;

  static StatedTitleView from(BuildContext context, String Function() getTitle) =>
      StatedTitleView(getTitle, style: Styles.titleTextStyle);

  @override
  State<StatefulWidget> createState() => _TitleState();

}

class _TitleState extends State<StatedTitleView> implements lnc.Observer {
  _TitleState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kServerStateChanged);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kServerStateChanged);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    if (name == NotificationNames.kServerStateChanged) {
      GlobalVariable shared = GlobalVariable();
      int state = shared.terminal.sessionStateOrder;
      Log.info('session state: $state');
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    int state = shared.terminal.sessionStateOrder;
    Log.info('session state: $state');
    if (mounted) {
      setState(() {
      });
    }
    if (state == SessionStateOrder.init.index) {
      // current user must be set before enter this page,
      // so just do connecting here.
      shared.terminal.reconnect();
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Text(
    _titleWithState(widget.getTitle()),
    style: widget.style,
  );

}

String _titleWithState(String title) {
  GlobalVariable shared = GlobalVariable();
  String? sub = shared.terminal.sessionStateText;
  if (sub == null) {
    // trim title
    if (VisualTextUtils.getTextWidth(title) > 25) {
      title = VisualTextUtils.getSubText(title, 22);
      title = '$title...';
    }
    return title;
  } else if (sub == 'Disconnected') {
    _testSpeed();
  }
  // trim title
  if (VisualTextUtils.getTextWidth(title) > 15) {
    title = VisualTextUtils.getSubText(title, 12);
    title = '$title...';
  }
  return '$title ($sub)';
}

void _testSpeed() async {
  StationSpeeder speeder = StationSpeeder();
  await speeder.reload();
  await speeder.testAll();
}


abstract class VisualTextUtils {

  /// Calculate visual width
  static int getTextWidth(String text) {
    int width = 0;
    int index;
    int code;
    for (index = 0; index < text.length; ++index) {
      code = text.codeUnitAt(index);
      if (0x0000 <= code && code <= 0x007F) {
        // Basic Latin (ASCII)
        width += 1;
      } else if (0x0080 <= code && code <= 0x07FF) {
        // Latin-1 Supplement to CJK Unified Ideographs
        // ASCII or Latin-1 Supplement (includes most Western European languages)
        width += 1;
      } else {
        // Assume other characters are wide (e.g., CJK characters)
        width += 2;
      }
    }
    return width;
  }

  static String getSubText(String text, int maxWidth) {
    int width = 0;
    int index;
    int code;
    for (index = 0; index < text.length; ++index) {
      code = text.codeUnitAt(index);
      if (0x0000 <= code && code <= 0x007F) {
        // Basic Latin (ASCII)
        width += 1;
      } else if (0x0080 <= code && code <= 0x07FF) {
        // Latin-1 Supplement to CJK Unified Ideographs
        // ASCII or Latin-1 Supplement (includes most Western European languages)
        width += 1;
      } else {
        // Assume other characters are wide (e.g., CJK characters)
        width += 2;
      }
      if (width > maxWidth) {
        break;
      }
    }
    if (index == 0) {
      return '';
    }
    return text.substring(0, index);
  }

}

