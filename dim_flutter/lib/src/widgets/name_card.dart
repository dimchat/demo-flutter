/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';

import '../network/image_factory.dart';
import '../network/image_view.dart';
import 'styles.dart';


/// NameCardView
class NameCardView extends StatelessWidget {
  const NameCardView({super.key, required this.content, this.onTap, this.onLongPress});

  final NameCard content;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: _widget(context),
  );

  Widget _widget(BuildContext context) {
    var colors = Facade.of(context).colors;
    var styles = Facade.of(context).styles;
    ImageViewFactory factory = ImageViewFactory();
    ID identifier = content.identifier;
    String? url = content.avatar;
    Widget image = url == null
        ? factory.fromID(identifier, width: 32, height: 32)
        : ImageView(url: url, width: 32, height: 32,);
    return Container(
      color: colors.pageMessageBackgroundColor,
      padding: Styles.pageMessagePadding,
      width: 200,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(
                Radius.elliptical(8, 8)
            ),
            child: SizedBox(
              width: 48, height: 48,
              // color: CupertinoColors.systemIndigo,
              child: image,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(content.name,
              maxLines: 2,
              style: styles.pageTitleTextStyle,
            ),
          ),
          const SizedBox(
            width: 16,
          ),
        ],
      ),
    );
  }

}


class ImageView extends StatefulWidget {
  const ImageView({super.key, required this.url,
    required this.width, required this.height});

  final String url;
  final double width;
  final double height;

  @override
  State<StatefulWidget> createState() => _ImageViewState();

}

class _ImageViewState extends State<ImageView> {

  ImageProvider? get image {
    ImageFactory factory = ImageFactory();
    ImageProvider? img = factory.getImage(widget.url);
    if (img == null) {
      factory.downloadImage(widget.url).then((image) {
        if (mounted) {
          setState(() {
          });
        }
      });
    }
    return img;
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? img = image;
    if (img == null) {
      return Icon(Styles.noImageIcon,
        size: widget.width,
        color: Styles.avatarDefaultColor,
      );
    }
    return Image(image: img,
      width: widget.width, height: widget.height,
      fit: BoxFit.cover,
    );
  }

}
