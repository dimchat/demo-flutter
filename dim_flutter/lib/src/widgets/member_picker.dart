import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';
import 'package:get/get.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import '../models/chat.dart';
import '../models/chat_contact.dart';
import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';

import 'table.dart';
import 'title.dart';


typedef MemberPickerCallback = void Function(Set<ID> members);

class MemberPicker extends StatefulWidget {
  const MemberPicker(this.candidates, {super.key, required this.onPicked});

  final Set<ID> candidates;

  final MemberPickerCallback onPicked;

  static void open(BuildContext context, Set<ID> candidates, {required MemberPickerCallback onPicked}) =>
      showPage(
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
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Select Participants'.tr),
      trailing: TextButton(child: Text('OK'.tr),
        onPressed: () {
          closePage(context);
          widget.onPicked(_selected);
        },
      ),
    ),
    body: buildSectionListView(
      enableScrollbar: true,
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
    color: Styles.colors.sectionHeaderBackgroundColor,
    padding: Styles.sectionHeaderPadding,
    child: Text(_parent.dataSource.getSection(section),
      style: Styles.sectionHeaderTextStyle,
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
    title: widget.info.getNameLabel(
      style: widget.isSelected ? const TextStyle(color: CupertinoColors.systemRed) : null,
    ),
    trailing: !widget.isSelected ? null : Icon(AppIcons.selectedIcon,
      color: Styles.colors.primaryTextColor,
    ),
    onTap: () => setState(() {
      GestureTapCallback? callback = widget.onTap;
      if (callback != null) {
        callback();
      }
    }),
  );

}

Future<Widget> previewMembers(List<ID> members) async {
  List<Widget> children = [];
  Conversation? chat;
  for (ID item in members) {
    chat = Conversation.fromID(item);
    if (chat == null) {
      assert(false, 'failed to get conversation: $item');
      continue;
    }
    children.add(Container(
      padding: const EdgeInsets.all(4),
      child: previewEntity(chat),
    ));
  }
  return Center(
    child: buildScrollView(
      enableScrollbar: true,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    ),
  );
}

Widget previewEntity(Conversation info, {double width = 48, double height = 48, TextStyle? textStyle}) => Column(
  children: [
    info.getImage(width: width, height: height,),
    SizedBox(
      width: width,
      child: info.getNameLabel(
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    ),
  ],
);
