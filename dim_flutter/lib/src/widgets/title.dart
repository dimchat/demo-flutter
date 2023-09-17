import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/shared.dart';
import '../models/station.dart';
import '../network/velocity.dart';
import 'styles.dart';

class StatedTitleView extends StatefulWidget {
  const StatedTitleView(this.getTitle, {required this.style, super.key});

  final String Function() getTitle;
  final TextStyle style;

  static StatedTitleView from(BuildContext context, String Function() getTitle) =>
      StatedTitleView(getTitle, style: Facade.of(context).styles.titleTextStyle);

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
    Map? info = notification.userInfo;
    if (name == NotificationNames.kServerStateChanged) {
      int state = _stateIndex(info?['current']);
      Log.debug('session state: $state');
      if (mounted) {
        setState(() {
          _sessionState = state;
        });
      }
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    int state = _stateIndex(shared.terminal.session?.state);
    Log.debug('session state: $state');
    if (mounted) {
      setState(() {
        _sessionState = state;
      });
    }
    if (state == SessionStateOrder.kDefault) {
      // current user must be set before enter this page,
      // so just do connecting here.
      _reconnect(false);
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

int _stateIndex(SessionState? state) =>
    state?.index ?? SessionStateOrder.kDefault;

int _sessionState = SessionStateOrder.kDefault;

String _titleWithState(String title) {
  String? sub;
  switch (_sessionState) {
    case SessionStateOrder.kDefault:
      sub = 'Waiting';  // waiting to connect
      break;
    case SessionStateOrder.kConnecting:
      sub = 'Connecting';
      break;
    case SessionStateOrder.kConnected:
      sub = 'Connected';
      break;
    case SessionStateOrder.kHandshaking:
      sub = 'Handshaking';
      break;
    case SessionStateOrder.kRunning:
      sub = null;  // normal running
      break;
    default:
      sub = 'Disconnected';
      _reconnect(true);
      break;
  }
  if (sub == null) {
    return title;
  } else if (title.length > 15) {
    title = '${title.substring(0, 12)}...';
  }
  return '$title ($sub)';
}

void _reconnect(bool test) async {
  GlobalVariable shared = GlobalVariable();
  if (test) {
    SessionDBI database = shared.sdb;
    List<ProviderInfo> records = await database.allProviders();
    ID pid;
    for (ProviderInfo provider in records) {
      pid = provider.identifier;
      var items = await database.allStations(provider: pid);
      List<NeighborInfo> stations = await NeighborInfo.fromList(items);
      // check all stations of this provider
      List<Future<VelocityMeter>> futures = [];
      for (NeighborInfo info in stations) {
        futures.add(VelocityMeter.ping(info));
      }
      // report speeds after all stations tested
      Future.wait(futures).then((meters) {
        shared.messenger?.reportSpeeds(meters, pid);
      });
    }
    await Future.delayed(const Duration(seconds: 3));
  } else {
    await Future.delayed(const Duration(seconds: 1));
  }
  await shared.terminal.reconnect();
}
