import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' show Log;

import '../models/chat_contact.dart';
import 'styles.dart';
import 'table.dart';
import 'title.dart';

typedef MemberPickerCallback = void Function(Set<ID> members);

class MemberPicker extends StatefulWidget {
  const MemberPicker(this.candidates, {super.key, required this.onPicked});

  final Set<ID> candidates;

  final MemberPickerCallback onPicked;

  static void open(BuildContext context, Set<ID> candidates, {required MemberPickerCallback onPicked}) =>
      showCupertinoDialog(
        context: context,
        builder: (context) => MemberPicker(candidates, onPicked: onPicked),
      );

  @override
  State<StatefulWidget> createState() => _MemberPickerState();

}

class _MemberPickerState extends State<MemberPicker> {
  _MemberPickerState() {
    _dataSource = _ContactDataSource();
    _adapter = _ContactListAdapter(this);
  }

  late final _ContactDataSource _dataSource;
  late final _ContactListAdapter _adapter;

  final Set<ID> _selected = HashSet();

  Set<ID> get selected => _selected;

  _ContactDataSource get dataSource => _dataSource;

  Future<void> _reload() async {
    List<ID> members = widget.candidates.toList();
    List<ContactInfo> array = ContactInfo.fromList(members);
    for (ContactInfo item in array) {
      await item.reloadData();
    }
    _dataSource.refresh(array);
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
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
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Select Participants'),
      trailing: TextButton(child: const Text('OK'),
        onPressed: () {
          Navigator.pop(context);
          widget.onPicked(_selected);
        },
      ),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _ContactListAdapter with SectionAdapterMixin {
  _ContactListAdapter(_MemberPickerState state)
      : _parent = state;

  final _MemberPickerState _parent;

  @override
  int numberOfSections() => _parent.dataSource.getSectionCount();

  @override
  bool shouldExistSectionHeader(int section) => true;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Facade.of(context).colors.sectionHeaderBackgroundColor,
    padding: Styles.sectionHeaderPadding,
    child: Text(_parent.dataSource.getSection(section),
      style: Facade.of(context).styles.sectionHeaderTextStyle,
    ),
  );

  @override
  int numberOfItems(int section) => _parent.dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section;
    int index = indexPath.item;
    ContactInfo info = _parent.dataSource.getItem(section, index);
    return _PickContactCell(_parent, info, onTap: () {
      Set<ID> members = _parent.selected;
      if (members.contains(info.identifier)) {
        members.remove(info.identifier);
      } else {
        members.add(info.identifier);
      }
      Log.info('selected members: $members');
    });
  }

}

class _ContactDataSource {

  List<String> _sections = [];
  Map<int, List<ContactInfo>> _items = {};

  void refresh(List<ContactInfo> contacts) {
    Log.debug('refreshing ${contacts.length} contact(s)');
    ContactSorter sorter = ContactSorter.build(contacts);
    _sections = sorter.sectionNames;
    _items = sorter.sectionItems;
  }

  int getSectionCount() => _sections.length;

  String getSection(int sec) => _sections[sec];

  int getItemCount(int sec) => _items[sec]?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items[sec]![idx];
}

/// TableCell for Contacts
class _PickContactCell extends StatefulWidget {
  const _PickContactCell(_MemberPickerState state, this.info, {this.onTap})
      : _parent = state;

  final _MemberPickerState _parent;

  final ContactInfo info;
  final GestureTapCallback? onTap;

  bool get isSelected => _parent.selected.contains(info.identifier);

  @override
  State<StatefulWidget> createState() => _PickContactState();

}

class _PickContactState extends State<_PickContactCell> {
  _PickContactState();

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: widget.info.getImage(),
    title: widget.info.getNameLabel(),
    trailing: widget.isSelected ? const Icon(Styles.selectedIcon) : null,
    onTap: () => setState(() {
      GestureTapCallback? callback = widget.onTap;
      if (callback != null) {
        callback();
      }
    }),
  );

}