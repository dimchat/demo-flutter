/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
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

import 'package:flutter/cupertino.dart';

import 'package:dim_client/ok.dart' as lnc;
import 'package:pnf/pnf.dart';

import '../ui/icons.dart';

import 'image.dart';
import 'loader.dart';
import 'net_base.dart';


/// View for show Image Content
class PortableImageView extends PortableNetworkView {
  const PortableImageView(super.loader, {this.width, this.height, this.fit, super.key});

  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  State<StatefulWidget> createState() => _PortableImageState();

}

class _PortableImageState extends PortableNetworkState<PortableImageView> implements lnc.Observer {

  @override
  Widget build(BuildContext context) {
    var loader = widget.loader as PortableImageLoader;
    Widget? indicator = loader.getProgress(widget);
    if (indicator == null) {
      return loader.getImage(widget, fit: widget.fit);
    }
    return Stack(
      alignment: AlignmentDirectional.center,
      // fit: StackFit.passthrough,
      children: [
        loader.getImage(widget, fit: widget.fit),
        indicator,
      ],
    );
  }

}


abstract class PortableImageLoader extends PortableFileLoader {
  PortableImageLoader(super.pnf);

  ImageProvider<Object>? _provider;

  ImageProvider<Object>? get imageProvider {
    var image = _provider;
    if (image == null) {
      // check file content
      Uint8List? bytes = plaintext;
      if (bytes != null && bytes.isNotEmpty) {
        image = _provider = ImageUtils.memoryImageProvider(bytes);
      // } else {
      //   // waiting to download & decrypt
      }
    }
    return image;
  }

  Widget getImage(PortableImageView widget, {BoxFit? fit});

  Widget? getProgress(PortableImageView widget) {
    PortableNetworkStatus pns = status;
    if (pns == PortableNetworkStatus.success ||
        pns == PortableNetworkStatus.init) {
      return null;
    }
    String text;
    IconData? icon;
    Color color = CupertinoColors.white;
    // check status
    if (pns == PortableNetworkStatus.error) {
      text = 'Error';
      icon = AppIcons.decryptErrorIcon;
      color = CupertinoColors.systemRed;
    } else if (pns == PortableNetworkStatus.downloading) {
      double len = total.toDouble();
      double value = len > 0 ? count * 100.0 / len : 0.0;
      if (value < 100.0) {
        text = '${value.toStringAsFixed(1)}%';
      } else {
        text = 'Decrypting';
        icon = AppIcons.decryptingIcon;
      }
    } else if (pns == PortableNetworkStatus.decrypting) {
      text = 'Decrypting';
      icon = AppIcons.decryptingIcon;
    } else if (pns == PortableNetworkStatus.waiting) {
      text = 'Waiting';
    } else {
      assert(false, 'status error: $pns');
      return null;
    }
    // check size
    double? width = widget.width;
    double? height = widget.height;
    if (width == null || height == null) {
      // size unlimited
    } else if (width < 64 || height < 64) {
      double size = width < height ? width : height;
      return _indicator(icon, color, size);
    }
    // indicator on tray
    return _tray(text, icon, color);
  }

  Widget _indicator(IconData? icon, Color color, double size) => Container(
    color: CupertinoColors.secondaryLabel,
    width: size,
    height: size,
    child: icon == null
        ? CupertinoActivityIndicator(color: color, radius: size/4,)
        : Icon(icon, color: color, size: size/2,),
  );

  Widget _tray(String text, IconData? icon, Color color) => ClipRRect(
    borderRadius: const BorderRadius.all(
      Radius.elliptical(8, 8),
    ),
    child: Container(
      color: CupertinoColors.secondaryLabel,
      width: 64,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon == null
              ? CupertinoActivityIndicator(color: color)
              : Icon(icon, color: color),
          Text(text,
            style: TextStyle(color: color, fontSize: 10,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    ),
  );

}
