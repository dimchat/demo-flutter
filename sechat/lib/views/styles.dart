// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

abstract class Styles {
  static const TextStyle productRowItemName = TextStyle(
    color: Color.fromRGBO(0, 0, 0, 0.8),
    fontSize: 18,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle productRowTotal = TextStyle(
    color: Color.fromRGBO(0, 0, 0, 0.8),
    fontSize: 18,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle productRowItemPrice = TextStyle(
    color: Color(0xFF8E8E93),
    fontSize: 13,
    fontWeight: FontWeight.w300,
  );

  static const TextStyle searchText = TextStyle(
    color: Color.fromRGBO(0, 0, 0, 1),
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle deliveryTimeLabel = TextStyle(
    color: Color(0xFFC2C2C2),
    fontWeight: FontWeight.w300,
  );

  static const TextStyle deliveryTime = TextStyle(
    color: CupertinoColors.inactiveGray,
  );

  static const Color productRowDivider = Color(0xFFD9D9D9);

  static const Color scaffoldBackground = Color(0xfff0f0f0);

  static const Color searchBackground = Color(0xffe0e0e0);

  static const Color searchCursorColor = Color.fromRGBO(0, 122, 255, 1);

  static const Color searchIconColor = Color.fromRGBO(128, 128, 128, 1);


  //
  //  Theme
  //
  static const Color themeBarBackgroundColor = CupertinoColors.white;

  //
  //  Navigation
  //
  static const Border navigationBarBorder = Border(
    bottom: BorderSide(
      color: Color(0x4D000000),
      width: 0.0, // 0.0 means one physical pixel
    ),
  );
  static const Color navigationBarBackground = CupertinoColors.systemBackground;
  static const Color navigationBarIconColor = CupertinoColors.systemBlue;
  static const double navigationBarIconSize = 16;

  static const backgroundColor = CupertinoColors.secondarySystemBackground;

  //
  //  Section
  //
  static const Color sectionHeaderBackground = CupertinoColors.lightBackgroundGray;
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.only(
      left: 16, top: 4, bottom: 4,
  );
  static const TextStyle sectionHeaderTextStyle = TextStyle(
    color: CupertinoColors.systemGrey,
    fontSize: 12,
  );

  static const Color sectionItemDividerColor = CupertinoColors.secondarySystemBackground;

  static const Color sectionItemBackground = CupertinoColors.systemBackground;
  static const EdgeInsets sectionItemMargin = EdgeInsets.only(
    bottom: 1,
  );
  static const EdgeInsets sectionItemPadding = EdgeInsets.only(
    left: 20, top: 4, bottom: 4,
  );
}
