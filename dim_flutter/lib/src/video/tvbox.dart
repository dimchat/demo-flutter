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
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:dim_client/dim_common.dart';
import 'package:lnc/log.dart';
import 'package:lnc/notification.dart' as lnc;
import 'package:pnf/http.dart';
import 'package:tvbox/lives.dart';

import '../common/constants.dart';
import '../widgets/table.dart';


class ChannelSource {
  ChannelSource(this.name, this.url);
  final String name;
  final Uri url;
}

class ChannelGroup {
  ChannelGroup(this.title, this.sources);
  final String title;
  final List<ChannelSource> sources;
}


class TVBox with Logging {
  TVBox(this.livesUrl);

  final Uri livesUrl;

  List<ChannelGroup>? lives;

  bool hidden = false;
  Widget? _view;

  Widget? get view {
    if (hidden) {
      return null;
    }
    Widget? v = _view;
    if (v == null) {
      _view = v = _livesView(lives);
    }
    return v;
  }

  Future<List<ChannelGroup>> refresh() async {
    var helper = _LiveHelper();
    //
    //  0. keep old records
    //
    var old = lives ?? [];
    lives = null;
    _view = null;
    //
    //  1. get from lives URL
    //
    var text = await helper.httpGet(livesUrl);
    if (text == null || text.isEmpty) {
      // restore the old records
      lives = old;
      logError('cannot get lives from $livesUrl');
      return old;
    }
    //
    //  2. parse lives
    //
    List<LiveGenre> genres = helper.parseLives(text);
    logInfo('got ${genres.length} genres from URL: $livesUrl');
    List<ChannelGroup> sections = [];
    for (var grp in genres) {
      List<ChannelSource> sources = [];
      var channels = grp.channels;
      for (var item in channels) {
        var name = item.name;
        var streams = item.streams;
        int index = 0;
        for (var src in streams) {
          var m3u8 = src.url;
          if (m3u8 == null) {
            logWarning('channel stream error: "${item.name}" -> $src');
            continue;
          } else {
            index += 1;
          }
          if (index > 1) {
            sources.add(ChannelSource('$name ($index)', m3u8));
          } else {
            sources.add(ChannelSource(name, m3u8));
          }
        }
      }
      sections.add(ChannelGroup(grp.title, sources));
    }
    // OK
    lives = sections;
    return sections;
  }

}


class _LiveHelper with Logging {
  factory _LiveHelper() => _instance;
  static final _LiveHelper _instance = _LiveHelper._internal();
  _LiveHelper._internal();

  //
  //  Lives
  //

  final LiveParser _parser = LiveParser();

  List<LiveGenre> parseLives(String text) => _parser.parse(text);

  //
  //  HTTP
  //

  final HTTPClient _http = HTTPClient();
  final Map<Uri, String> _caches = {};

  Future<String?> httpGet(Uri url) async {
    // get from cache
    String? text = _caches[url];
    if (text == null) {
      // get from remote url
      Uint8List? data = await _http.download(url);
      if (data == null) {
        logError('failed to download: $url');
      } else {
        text = UTF8.decode(data);
        if (text == null) {
          logError('failed to decode ${data.length} bytes from $url');
        } else {
          // cache it
          _caches[url] = text;
        }
      }
    }
    return text;
  }

}

Widget? _livesView(List<ChannelGroup>? groups) {
  if (groups == null) {
    return null;
  }
  var secs = const TextStyle(
    color: Colors.yellow,
    fontSize: 24,
    decoration: TextDecoration.none,
  );
  var opts = const TextStyle(
    color: Colors.white,
    fontSize: 16,
    decoration: TextDecoration.none,
  );

  List<Widget> children = [];
  for (var grp in groups) {
    children.add(Text(grp.title, style: secs,));
    var sources = grp.sources;
    for (var src in sources) {
      children.add(_livesButton(src, style: opts));
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
    color: Colors.grey.withAlpha(0x77),
    child: view,
  );
  return view;
}

Widget _livesButton(ChannelSource src, {required TextStyle style,}) {
  Uri url = _getLiveUrl(src);
  String title = _getLiveTitle(src);
  Widget view = Text(src.name, style: style,);
  return TextButton(
    onPressed: () => _postPlay(url, title),
    child: view,
  );
}

void _postPlay(Uri url, String title) {
  var nc = lnc.NotificationCenter();
  nc.postNotification(NotificationNames.kVideoPlayerPlay, null, {
    'url': url,
    'title': title,
  });
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
