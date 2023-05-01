import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/shared.dart';
import '../models/station.dart';
import '../network/velocity.dart';

class StatedTitleView extends StatefulWidget {
  const StatedTitleView(this.getTitle, {super.key});

  final String Function() getTitle;

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
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kServerStateChanged);
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
  Widget build(BuildContext context) => Text(_titleWithState(widget.getTitle()));

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
  return sub == null ? title : '$title ($sub)';
}

void _reconnect(bool test) async {
  GlobalVariable shared = GlobalVariable();
  if (test) {
    SessionDBI database = shared.sdb;
    List<Pair<ID, int>> records = await database.getProviders();
    for (Pair<ID, int> provider in records) {
      var items = await database.getStations(provider: provider.first);
      List<StationInfo> stations = await StationInfo.fromList(items);
      for (StationInfo srv in stations) {
        VelocityMeter.ping(srv);
      }
    }
    await Future.delayed(const Duration(seconds: 5));
  } else {
    await Future.delayed(const Duration(seconds: 2));
  }
  await shared.terminal.reconnect();
}
