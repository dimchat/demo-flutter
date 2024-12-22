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

import 'package:dim_client/sdk.dart';

import '../pnf/auto_avatar.dart';
import '../ui/styles.dart';


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

  static Widget avatarImage(NameCard content, {double? width, double? height, BoxFit? fit}) {
    width ??= 48;
    height ??= 48;
    var factory = AvatarFactory();
    ID identifier = content.identifier;
    var avatar = content.avatar;
    if (avatar == null) {
      return factory.getAvatarView(identifier, width: width, height: height, fit: fit);
    }
    var view = factory.getImageView(identifier, avatar, width: width, height: height, fit: fit);
    return ClipRRect(
      borderRadius: BorderRadius.all(
        Radius.elliptical(width / 8, height / 8),
      ),
      child: view,
    );
  }

  Widget _widget(BuildContext context) => Container(
    color: Styles.colors.pageMessageBackgroundColor,
    padding: Styles.pageMessagePadding,
    width: 200,
    child: Row(
      children: [
        avatarImage(content, width: 48, height: 48,),
        const SizedBox(width: 8,),
        Expanded(
          child: Text(content.name,
            maxLines: 2,
            style: Styles.pageTitleTextStyle,
          ),
        ),
        const SizedBox(
          width: 16,
        ),
      ],
    ),
  );

}


// class ImageView extends StatefulWidget {
//   const ImageView({super.key, required this.url,
//     required this.width, required this.height});
//
//   final String url;
//   final double width;
//   final double height;
//
//   @override
//   State<StatefulWidget> createState() => _ImageViewState();
//
// }
//
// class _ImageViewState extends State<ImageView> {
//
//   ImageProvider? get image {
//     ImageFactory factory = ImageFactory();
//     ImageProvider? img = factory.getImage(widget.url);
//     if (img == null) {
//       factory.downloadImage(widget.url).then((image) {
//         if (mounted) {
//           setState(() {
//           });
//         }
//       });
//     }
//     return img;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     ImageProvider? img = image;
//     if (img == null) {
//       return Icon(AppIcons.noImageIcon,
//         size: widget.width,
//         color: Styles.colors.avatarDefaultColor,
//       );
//     }
//     return ImageUtils.image(img,
//       width: widget.width, height: widget.height,
//       fit: BoxFit.cover,
//     );
//   }
//
// }
