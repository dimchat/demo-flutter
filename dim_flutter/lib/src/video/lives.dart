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

import 'package:lnc/notification.dart' as lnc;

import '../common/constants.dart';
import '../widgets/table.dart';

import 'tvbox.dart';


///
/// Text Styles
///
const TextStyle channelGroupStyle = TextStyle(
  color: Colors.yellow,
  fontSize: 24,
  decoration: TextDecoration.none,
);
const TextStyle channelSourceStyle = TextStyle(
  color: Colors.white,
  fontSize: 16,
  decoration: TextDecoration.none,
);
const TextStyle playingSourceStyle = TextStyle(
  color: Colors.blue,
  fontSize: 16,
  decoration: TextDecoration.none,
);


class LiveChannelListPage extends StatelessWidget {
  const LiveChannelListPage(this.tvBox, {super.key});

  final TVBox tvBox;

  @override
  Widget build(BuildContext context) {
    List<ChannelGroup>? groups = tvBox.lives;
    if (groups == null || groups.isEmpty) {
      // empty
      return Container();
    }
    List<Widget> children = [];
    for (var grp in groups) {
      // channel group
      children.add(Text(grp.title, style: channelGroupStyle,));
      var sources = grp.sources;
      for (var src in sources) {
        // channel source
        children.add(_LiveChannelButton(src, tvBox));
      }
    }
    Widget view = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    view = Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: view,
    );
    view = buildScrollView(
      child: view,
    );
    view = Container(
      color: Colors.black.withAlpha(0x77),
      child: view,
    );
    return view;
  }

}

class _LiveChannelButton extends StatefulWidget {
  const _LiveChannelButton(this.source, this.tvBox);

  final ChannelSource source;
  final TVBox tvBox;

  @override
  State<StatefulWidget> createState() => _LiveChannelState();

}

class _LiveChannelState extends State<_LiveChannelButton> implements lnc.Observer {
  _LiveChannelState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kVideoPlayerPlay);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kVideoPlayerPlay);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    if (name == NotificationNames.kConversationUpdated) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var src = widget.source;
    var tvBox = widget.tvBox;
    Uri url = _getLiveUrl(src);
    String title = _getLiveTitle(src);
    String name = src.name;
    int index = src.sourceIndex;
    if (index > 1) {
      name += ' ($index)';
    }
    bool isPlaying = src == tvBox.playingItem;
    Widget view = Text(name, style: isPlaying ? playingSourceStyle : channelSourceStyle,);
    return TextButton(
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
  }

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
