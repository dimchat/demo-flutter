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
    FutureOr<void> Function()? onTap
  }) {
    return cell1(leading: leading, title: title, subtitle: subtitle, trailing: trailing, onTap: onTap);
    // return cell2(leading: leading, title: title, trailing: trailing, onTap: onTap);
  }

  static Widget cell1({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    FutureOr<void> Function()? onTap
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
    Widget? trailing,
    FutureOr<void> Function()? onTap
  }) => Container(
    color: Styles.sectionItemBackground,
    // margin: Styles.sectionItemMargin,
    child: Column(
      children: [
        CupertinoListTile(
          padding: Styles.sectionItemPadding,
          backgroundColor: Styles.sectionItemBackground,
          leading: leading,
          title: title,
          trailing: trailing,
          onTap: onTap,
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
}
