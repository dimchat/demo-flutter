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
import 'package:tvbox/lives.dart';

import '../common/constants.dart';
import '../ui/styles.dart';
import '../widgets/table.dart';

import 'tvbox.dart';


class LiveChannelListPage extends StatefulWidget {
  const LiveChannelListPage(this.tvBox, {super.key});

  final TVBox tvBox;

  static const String kPlayerChannelsRefresh = 'PlayerChannelsRefresh';

  @override
  State<LiveChannelListPage> createState() => _LiveChannelListState();
}

class _LiveChannelListState extends State<LiveChannelListPage> implements lnc.Observer {
  _LiveChannelListState() {
    _adapter = _LiveChannelAdapter(this);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, LiveChannelListPage.kPlayerChannelsRefresh);
  }

  late final _LiveChannelAdapter _adapter;

  TVBox get tvBox => widget.tvBox;

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    assert(name == LiveChannelListPage.kPlayerChannelsRefresh, 'notification error: $notification');
    if (mounted) {
      setState(() {
      });
    }
  }

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
    ChannelStream src = getSource(indexPath.section, indexPath.item)!;
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

  List<LiveGenre> get groups => state.widget.tvBox.lives ?? [];
  int getGroupCount() => groups.length;
  LiveGenre getGroup(int sec) => groups[sec];

  int getSourceCount(int sec) {
    var channels = groups[sec].channels;
    int count = 0;
    for (var item in channels) {
      count += _testSpaces(item);
    }
    return count;
  }
  int _testSpaces(LiveChannel item) {
    var unfold = item.getValue('unfold', null);
    if (unfold != true) {
      return 1;
    }
    int count = item.count;
    if (count == 1) {
      return 1;
    }
    return count + 1;
  }

  ChannelStream? getSource(int sec, int idx) {
    var channels = groups[sec].channels;
    for (var item in channels) {
      // check channel size
      int count = item.count;
      int spaces;
      var unfold = item.getValue('unfold', null);
      if (unfold != true) {
        spaces = 1;
      } else {
        spaces = count;
        if (spaces > 1) {
          spaces += 1;
        }
      }
      if (idx >= spaces) {
        idx -= spaces;
        continue;
      } else if (idx > 0) {
        var src = item.streams[idx - 1];
        return ChannelStream(item, src);
      } else if (count == 1) {
        var src = item.streams[0];
        return ChannelStream(item, src);
      } else {
        return ChannelStream(item, null);
      }
    }
    assert(false, 'failed to get source $sec, $idx');
    return null;
  }

}

Widget _getChannelButton(ChannelStream src, TVBox tvBox) {
  bool isPlaying = src == tvBox.playingItem;
  var channel = src.channel;
  var stream = src.stream;
  if (stream == null) {
    var name = channel.name;
    var count = channel.count;
    var unfold = channel.getValue('unfold', null);
    if (unfold != true) {
      name += '  ($count SRCS)';
    }
    return TextButton(
      onPressed: () {
        channel.setValue('unfold', unfold != true);
        // post notification
        var nc = lnc.NotificationCenter();
        nc.postNotification('PlayerChannelsRefresh', null, {});
      },
      child: Text(name,
        style: isPlaying ? Styles.livePlayingStyle : Styles.liveChannelStyle,
        softWrap: false,
        overflow: TextOverflow.fade,
        maxLines: 1,
      ),
    );
  }
  var name = channel.name;
  var count = channel.count;
  if (count > 1) {
    String? label = stream.label;
    int index = stream.getValue('index', 0);
    if (label == null || label.isEmpty) {
      name = '    #$index  Live Source';
    } else {
      name = '    #$index  $label';
    }
  }
  Widget view = Text(name,
    style: isPlaying ? Styles.livePlayingStyle : Styles.liveChannelStyle,
    softWrap: false,
    overflow: TextOverflow.fade,
    maxLines: 1,
  );
  Uri? url = _getLiveUrl(stream.url);
  view = TextButton(
    onPressed: isPlaying ? null : () {
      var nc = lnc.NotificationCenter();
      nc.postNotification(NotificationNames.kVideoPlayerPlay, null, {
        'url': url,
        'title': _getLiveTitle(src),
      });
      tvBox.playingItem = src;
    },
    child: view,
  );
  return view;
}

Uri? _getLiveUrl(Uri? url) {
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

String _getLiveTitle(ChannelStream src) {
  String name = src.channel.name;
  if (name.toUpperCase().endsWith(' - LIVE')) {
    return name;
  }
  return '$name - LIVE';
}
