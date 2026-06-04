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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:pnf/http.dart';
import 'package:tvbox/lives.dart';

import 'lives.dart';


class ChannelStream {
  ChannelStream(this.channel, this.stream);

  final LiveChannel channel;
  final LiveStream? stream;

  @override
  bool operator ==(Object other) {
    if (other is ChannelStream) {
      var src = stream;
      if (src == null) {
        return other.channel == channel;
      } else {
        return other.stream == src;
      }
    }
    return false;
  }

  @override
  int get hashCode => stream?.hashCode ?? channel.hashCode;

}


class TVBox extends Dictionary with Logging {
  TVBox(this.livesUrl, super.dict);

  final Uri livesUrl;

  ChannelStream? playingItem;

  List<LiveGenre>? lives;

  bool hidden = false;

  Widget? get view => LiveChannelListPage(this);

  Future<List<LiveGenre>> refresh() async {
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
    List<LiveGenre> sections = [];
    for (var grp in genres) {
      List<LiveChannel> items = [];
      var channels = grp.channels;
      for (var mem in channels) {
        List<LiveStream> sources = [];
        var streams = mem.streams;
        int index = 0;
        for (var src in streams) {
          var m3u8 = src.url;
          if (m3u8 == null) {
            logWarning('channel stream error: "${mem.name}" -> $src');
            continue;
          } else {
            index += 1;
          }
          src.setValue('index', index);
          sources.add(src);
        }
        if (sources.isNotEmpty) {
          items.add(LiveChannel({
            'name': mem.name,
            'streams': sources,
          }));
        }
      }
      if (items.isNotEmpty) {
        sections.add(LiveGenre({
          'title': grp.title,
          'channels': items,
        }));
      }
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

  final FileDownloader _http = FileDownloader(HTTPClient());
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
