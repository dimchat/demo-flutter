/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:lnc/notification.dart' as lnc;

import '../common/constants.dart';
import '../ui/styles.dart';
import '../widgets/table.dart';

import 'tvbox.dart';


class LiveChannelListPage extends StatefulWidget {
  const LiveChannelListPage(this.tvBox, {super.key});

  final TVBox tvBox;

  @override
  State<LiveChannelListPage> createState() => _LiveChannelListState();
}

class _LiveChannelListState extends State<LiveChannelListPage> {
  _LiveChannelListState() {
    _adapter = _LiveChannelAdapter(this);
  }

  late final _LiveChannelAdapter _adapter;

  TVBox get tvBox => widget.tvBox;

  @override
  Widget build(BuildContext context) {
    Widget view = buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    );
    view = Container(
      width: 220,
      color: Colors.black.withAlpha(0x77),
      child: view,
    );
    return view;
  }

}


//
//  Section Adapter
//

class _LiveChannelAdapter with SectionAdapterMixin {
  _LiveChannelAdapter(this.state);

  final _LiveChannelListState state;

  @override
  bool shouldExistSectionHeader(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    var group = getGroup(section);
    Widget view = Text(group.title,
      style: Styles.liveGroupStyle,
      softWrap: false,
      overflow: TextOverflow.fade,
      maxLines: 1,
    );
    return Center(
      child: view,
    );
  }

  @override
  int numberOfSections() => getGroupCount();

  @override
  int numberOfItems(int section) => getSourceCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    ChannelSource src = getSource(indexPath.section, indexPath.item);
    Widget view = _getChannelButton(src, state.tvBox);
    view = Container(
      alignment: Alignment.centerLeft,
      child: view,
    );
    return view;
  }

  //
  //  Data Source
  //
  List<ChannelGroup> get groups => state.widget.tvBox.lives ?? [];
  int getGroupCount() => groups.length;
  ChannelGroup getGroup(int sec) => groups[sec];
  int getSourceCount(int sec) => groups[sec].sources.length;
  ChannelSource getSource(int sec, int idx) => groups[sec].sources[idx];

}

Widget _getChannelButton(ChannelSource src, TVBox tvBox) {
  Uri url = _getLiveUrl(src);
  String title = _getLiveTitle(src);
  String name = src.name;
  int index = src.sourceIndex;
  if (index > 1) {
    name += ' ($index)';
  }
  bool isPlaying = src == tvBox.playingItem;
  Widget view = Text(name,
    style: isPlaying ? Styles.livePlayingStyle : Styles.liveChannelStyle,
    softWrap: false,
    overflow: TextOverflow.fade,
    maxLines: 1,
  );
  view = TextButton(
    onPressed: isPlaying ? null : () {
      var nc = lnc.NotificationCenter();
      nc.postNotification(NotificationNames.kVideoPlayerPlay, null, {
        'url': url,
        'title': title,
      });
      tvBox.playingItem = src;
    },
    child: view,
  );
  return view;
}

Uri _getLiveUrl(ChannelSource src) {
  Uri url = src.url;
  String urlString = url.toString();
  if (urlString.endsWith(r'#live') || urlString.contains(r'#live/')) {
    return url;
  } else if (urlString.contains(r'm3u8')) {
    urlString += '#live/stream.m3u8';
  } else {
    urlString += '#live';
  }
  try {
    return Uri.parse(urlString);
  } catch (e) {
    return url;
  }
}

String _getLiveTitle(ChannelSource src) {
  String name = src.name;
  if (name.toUpperCase().endsWith(' - LIVE')) {
    return name;
  }
  return '$name - LIVE';
}
