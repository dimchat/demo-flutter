import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

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
      Log.debug('session state: $state');
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    int state = shared.terminal.sessionStateOrder;
    Log.debug('session state: $state');
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
    return title;
  } else if (sub == 'Disconnected') {
    _testSpeed();
  }
  if (title.length > 15) {
    title = '${title.substring(0, 12)}...';
  }
  return '$title ($sub)';
}

void _testSpeed() async {
  StationSpeeder speeder = StationSpeeder();
  await speeder.reload();
  await speeder.testAll();
}
