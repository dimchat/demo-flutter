/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
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
import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/material.dart';

import '../ui/icons.dart';
import '../widgets/video_player.dart';
import 'gallery.dart';
import 'image.dart';
import 'loader.dart';
import 'net_base.dart';


/// Factory for Remote Video
class NetworkVideoFactory {
  factory NetworkVideoFactory() => _instance;
  static final NetworkVideoFactory _instance = NetworkVideoFactory._internal();
  NetworkVideoFactory._internal();

  PortableNetworkView getVideoView(VideoContent content,
      {double? width, double? height, OnVideoShare? onVideoShare}) {
    PortableNetworkFile? pnf = PortableNetworkFile.parse(content);
    Uri? url = pnf?.url;
    if (url == null || pnf == null) {
      throw FormatException('PNF error: $content');
    }
    _PortableVideoLoader loader = _PortableVideoLoader.from(pnf);
    return _PortableVideoView(loader, width: width, height: height, onVideoShare: onVideoShare,);
  }

}


/// View for show Video Content
class _PortableVideoView extends PortableNetworkView {
  const _PortableVideoView(super.loader, {this.width, this.height, this.onVideoShare});

  Uri? get url => pnf.url;

  final double? width;
  final double? height;

  final OnVideoShare? onVideoShare;

  @override
  State<StatefulWidget> createState() => _PortableVideoState();

  static Widget getNoImage({double? width, double? height}) {
    width ??= 160;
    height ??= 90;
    return Container(
      width: width,
      height: height,
      color: CupertinoColors.black,
    );
  }

}

class _PortableVideoState extends PortableNetworkState<_PortableVideoView> {

  @override
  Widget build(BuildContext context) {
    var loader = widget.loader as _PortableVideoLoader;
    Widget? indicator = loader.getProgress(context, widget);
    if (indicator == null) {
      return loader.getImage(widget);
    }
    String? title = widget.pnf.getString('title', null);
    String? cover = widget.pnf.getString('snapshot', null);
    return Stack(
      alignment: AlignmentDirectional.center,
      // fit: StackFit.passthrough,
      children: [
        loader.getImage(widget),
        if (cover == null && title != null)
          _titleWidget(title),
        indicator,
      ],
    );
  }

  Widget _titleWidget(String title) {
    String name;
    int pos = title.indexOf('; cover=');
    if (pos > 0) {
      title = title.substring(0, pos);
    }
    pos = title.indexOf(' - ');
    if (pos > 0) {
      name = title.substring(0, pos).trim();
      title = title.substring(pos + 3).trim();
    } else {
      name = title.trim();
      title = '';
    }
    return Text('$name\n\n$title',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
      ),
    );
  }

}


class _PortableVideoLoader extends PortableFileLoader {
  _PortableVideoLoader(super.pnf);

  ImageProvider<Object>? _snapshot;

  ImageProvider<Object>? get imageProvider {
    var image = _snapshot;
    image ??= _snapshot = Gallery.getSnapshotProvider(pnf);
    return image;
  }

  Widget getImage(_PortableVideoView widget) {
    double? width = widget.width;
    double? height = widget.height;
    var image = imageProvider;
    if (image == null) {
      return _PortableVideoView.getNoImage(width: width, height: height);
    } else if (width == null && height == null) {
      return ImageUtils.image(image,);
    } else {
      return ImageUtils.image(image, width: width, height: height, fit: BoxFit.cover,);
    }
  }

  Widget? getProgress(BuildContext ctx, _PortableVideoView widget) {
    PortableNetworkFile pnf = widget.pnf;
    var url = pnf.url;
    if (url == null) {
      return _showError('URL not found', null, CupertinoColors.systemRed);
    }
    var password = pnf.password;
    if (password != null && password.algorithm != PlainKey.kPLAIN) {
      return _showError('Download not supported', null, CupertinoColors.systemRed);
    }
    var icon = const Icon(AppIcons.playVideoIcon, color: CupertinoColors.white);
    var button = IconButton(
      icon: icon,
      onPressed: () => VideoPlayerPage.open(ctx, url, pnf, onShare: widget.onVideoShare),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.elliptical(16, 16),
      ),
      child: Container(
        color: CupertinoColors.secondaryLabel,
        child: button,
      ),
    );
  }

  Widget _showError(String text, IconData? icon, Color color) => Container(
    color: CupertinoColors.secondaryLabel,
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text,
          style: TextStyle(color: color,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    ),
  );

  //
  //  Factory
  //
  static _PortableVideoLoader from(PortableNetworkFile pnf) {
    _PortableVideoLoader loader = _PortableVideoLoader(pnf);
    // if (pnf.url != null && pnf.data == null) {
    //   FileUploader().addDownloadTask(loader);
    // }
    return loader;
  }

}
