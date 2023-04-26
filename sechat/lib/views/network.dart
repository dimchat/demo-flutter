import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_client/dim_client.dart';
import 'package:dim_client/dim_client.dart' as lnc;

import '../client/constants.dart';
import '../client/shared.dart';
import '../models/station.dart';
import '../network/velocity.dart';
import '../widgets/tableview.dart';
import 'styles.dart';

class NetworkSettingPage extends StatefulWidget {
  const NetworkSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _NetworkState();

}

class _NetworkState extends State<NetworkSettingPage> {
  _NetworkState() {
    _dataSource = _StationDataSource();
    _adapter = _StationListAdapter(dataSource: _dataSource);
  }

  late final _StationDataSource _dataSource;
  late final _StationListAdapter _adapter;

  Future<void> _reload() async {
    await _dataSource.reload();
    if (mounted) {
      setState(() {

      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.backgroundColor,
    appBar: const CupertinoNavigationBar(
      backgroundColor: Styles.navigationBarBackground,
      border: Styles.navigationBarBorder,
      middle: Text('Relay Stations'),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _StationListAdapter with SectionAdapterMixin {
  _StationListAdapter({required _StationDataSource dataSource})
      : _dataSource = dataSource;

  final _StationDataSource _dataSource;

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount();

  @override
  bool shouldExistSectionHeader(int section) => true;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Styles.sectionHeaderBackground,
    padding: Styles.sectionHeaderPadding,
    child: Text(_dataSource.getSection(section),
      style: Styles.sectionHeaderTextStyle,
    ),
  );

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _StationCell(_dataSource.getItem(indexPath.section, indexPath.item));

}

class _StationDataSource {

  List<Pair<ID, int>> _sections = [];
  final Map<ID, List<StationInfo>> _items = {};

  Future<void> reload() async {
    GlobalVariable shared = GlobalVariable();
    SessionDBI database = shared.sdb;
    var providers = await database.getProviders();
    for (var item in providers) {
      var stations = await database.getStations(provider: item.first);
      _items[item.first] = await StationInfo.fromList(stations);
    }
    _sections = providers;
  }

  int getSectionCount() => _sections.length;

  String getSection(int sec) {
    ID pid = _sections[sec].first;
    return 'Provider ($pid)';
  }

  int getItemCount(int sec) {
    ID pid = _sections[sec].first;
    return _items[pid]?.length ?? 0;
  }

  StationInfo getItem(int sec, int idx) {
    ID pid = _sections[sec].first;
    return _items[pid]![idx];
  }
}

/// TableCell for Station
class _StationCell extends StatefulWidget {
  const _StationCell(this.info);

  final StationInfo info;

  @override
  State<StatefulWidget> createState() => _StationCellState();

}

class _StationCellState extends State<_StationCell> implements lnc.Observer {
  _StationCellState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kStationSpeedUpdated);
  }

  @override
  void dispose() {
    super.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kStationSpeedUpdated);
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kStationSpeedUpdated) {
      VelocityMeter meter = userInfo!['meter'];
      if (meter.port != widget.info.port || meter.host != widget.info.host) {
        return;
      }
      String state = userInfo['state'];
      Log.debug('test state: $state, $meter');
      if (state == 'start') {
        Log.debug('start to test station speed: $meter');
        setState(() {
          widget.info.testTime = DateTime.now();
          widget.info.responseTime = null;
        });
      } else if (state == 'connected') {
        Log.debug('connected to station: $meter');
      } else if (state == 'failed' || meter.responseTime == null) {
        Log.error('speed task failed: $meter, $state');
        setState(() {
          widget.info.testTime = DateTime.now();
          widget.info.responseTime = -1;
        });
      } else {
        assert(state == 'finished', 'meta state error: $userInfo');
        Log.debug('refreshing $meter -> ${widget.info}, $state');
        setState(() {
          widget.info.testTime = DateTime.now();
          widget.info.responseTime = meter.responseTime;
        });
      }
    } else {
      Log.error('notification error: $notification');
    }
  }

  void _reload() async {
    await widget.info.reloadData();
    setState(() {
    });
    await VelocityMeter.ping(widget.info);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => TableView.cell(
    leading: _getChosen(widget.info),
    title: Text(_getName(widget.info)),
    subtitle: Text('${widget.info.host}:${widget.info.port}'),
    trailing: Text(_getResult(widget.info),
      style: TextStyle(
        fontSize: 10,
        color: _getColor(widget.info),
      ),
    ),
  );

  String _getName(StationInfo info) {
    String? name = info.name;
    name ??= info.identifier?.string;
    if (name != null && name.isNotEmpty) {
      return name;
    } else {
      return '${info.host}:${info.port}';
    }
  }
  Icon _getChosen(StationInfo info) {
    if (info.chosen == 0) {
      return const Icon(CupertinoIcons.cloud);
    } else {
      return const Icon(CupertinoIcons.cloud_fill);
    }
  }
  String _getResult(StationInfo info) {
    double? responseTime = info.responseTime;
    if (info.testTime == null) {
      return 'unknown';
    } else if (responseTime == null) {
      return 'testing';
    } else if (responseTime < 0) {
      return 'error';
    }
    return '${responseTime.toStringAsFixed(3)}"';
  }
  Color _getColor(StationInfo info) {
    double? responseTime = info.responseTime;
    if (info.testTime == null) {
      return CupertinoColors.systemGrey;
    } else if (responseTime == null) {
      return CupertinoColors.systemBlue;
    } else if (responseTime <= 0.0) {
      return CupertinoColors.systemRed;
    } else if (responseTime > 15.0) {
      return CupertinoColors.systemYellow;
    }
    return CupertinoColors.systemGreen;
  }

}
