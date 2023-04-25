import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import '../client/shared.dart';
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
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section;
    int index = indexPath.item;
    _StationInfo info = _dataSource.getItem(section, index);
    String host = info.first.first;
    int port = info.first.second;
    return TableView.cell(
      leading: const Icon(CupertinoIcons.cloud),
      title: Text(host),
      trailing: Text('$port'),
    );
  }

}

class _StationDataSource {

  List<Pair<ID, int>> _sections = [];
  final Map<ID, List<_StationInfo>> _items = {};

  Future<void> reload() async {
    GlobalVariable shared = GlobalVariable();
    SessionDBI database = shared.sdb;
    List<Pair<ID, int>> providers = await database.getProviders();
    List<_StationInfo> stations;
    for (var item in providers) {
      stations = await database.getStations(provider: item.first);
      _items[item.first] = stations;
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

  _StationInfo getItem(int sec, int idx) {
    ID pid = _sections[sec].first;
    return _items[pid]![idx];
  }
}

typedef _StationInfo = Triplet<Pair<String, int>, ID, int>;
