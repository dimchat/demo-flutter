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
import 'package:pnf/http.dart';
import 'package:tvbox/lives.dart';

import 'lives.dart';


class ChannelSource {
  ChannelSource(this.name, this.url, this.sourceIndex);

  final String name;
  final Uri url;
  final int sourceIndex;

  @override
  bool operator ==(Object other) {
    if (other is ChannelSource) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      return url == other.url;
    }
    return false;
  }

  @override
  int get hashCode => url.hashCode;

}

class ChannelGroup {
  ChannelGroup(this.title, this.sources);

  final String title;
  final List<ChannelSource> sources;

}


class TVBox with Logging {
  TVBox(this.livesUrl);

  final Uri livesUrl;

  ChannelSource? playingItem;

  List<ChannelGroup>? lives;

  bool hidden = false;

  Widget? get view => LiveChannelListPage(this);

  Future<List<ChannelGroup>> refresh() async {
    var helper = _LiveHelper();
    //
    //  0. keep old records
    //
    var old = lives ?? [];
    lives = null;
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
          sources.add(ChannelSource(name, m3u8, index));
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
