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
import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../views/styles.dart';

class TableView {

  static const Widget defaultTrailing = CupertinoListTileChevron();

  // default style
  static Widget cell({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
  }) => cell2(leading: leading,
      title: title, subtitle: subtitle,
      trailing: trailing,
      onTap: onTap, onLongPress: onLongPress);

  static Widget cell1({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    FutureOr<void> Function()? onTap,
  }) => Container(
    color: Styles.sectionItemBackground,
    // margin: Styles.sectionItemMargin,
    child: Column(
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.all(16),
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onTap: onTap,
          backgroundColor: Styles.sectionItemBackground,
        ),
        Container(
          margin: const EdgeInsetsDirectional.only(
            start: 60,
          ),
          color: Styles.sectionItemDividerColor,
          height: 1,
        ),
      ],
    ),
  );

  static Widget cell2({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
  }) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 8),
          color: Styles.sectionItemBackground,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                alignment: Alignment.center,
                child: leading,
              ),
              Expanded(child: _cellBody(title: title, subtitle: subtitle),),
              Container(
                padding: const EdgeInsets.all(8),
                child: trailing,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          color: Styles.sectionItemBackground,
          child: Container(
            margin: const EdgeInsetsDirectional.only(start: 60),
            color: Styles.sectionItemDividerColor,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

Widget _cellBody({required Widget title, required Widget? subtitle}) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: DefaultTextStyle(
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontSize: 16,
          color: CupertinoColors.black,
          overflow: TextOverflow.ellipsis,
        ),
        child: title,
      ),
    ),
    if (subtitle != null)
      DefaultTextStyle(
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontSize: 10,
          color: CupertinoColors.systemGrey,
          overflow: TextOverflow.fade,
        ),
        child: subtitle,
      ),
  ],
);
