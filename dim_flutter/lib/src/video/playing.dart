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
import 'package:dim_client/sdk.dart';
import 'package:pnf/dos.dart';
import 'package:tvbox/lives.dart';


class MediaItem extends Dictionary {
  MediaItem(super.dict);

  /// M3U8
  Uri? get url {
    var m3u8 = getString('url', null);
    m3u8 ??= getString('URL', null);
    return m3u8 == null ? null : LiveStream.parseUri(m3u8);
  }

  /// name
  String get title => getString('title', null)
      ?? getString('name', null)
      ?? getString('url', null)
      ?? getString('URL', null)
      ?? '';

  String? get filename => getString('filename', null);

  /// snapshot
  Uri? get cover {
    var jpeg = getString('cover', null);
    jpeg ??= getString('snapshot', null);
    return jpeg == null ? null : LiveStream.parseUri(jpeg);
  }

  /// update values
  void refresh(Map info) {
    clear();
    info.forEach((key, value) => this[key] = value);
  }

  //
  //  Factory
  //

  static MediaItem create(Uri m3u8, {
    required String title,
    String? filename,
    Uri? cover,
  }) => MediaItem({
    'URL': m3u8.toString(),
    'url': m3u8.toString(),
    'title': title,
    'filename': filename ?? Paths.filename(m3u8.path),
    'cover': cover?.toString(),
    'snapshot': cover?.toString(),
  });

}


typedef OnVideoShare = void Function(MediaItem playingItem);
