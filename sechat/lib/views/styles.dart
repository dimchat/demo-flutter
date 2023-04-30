// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

abstract class Styles {

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
  static const Color sectionHeaderBackground = CupertinoColors.secondarySystemBackground;
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.fromLTRB(16, 4, 16, 4);
  static const TextStyle sectionHeaderTextStyle = TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  static const Color sectionItemDividerColor = CupertinoColors.secondarySystemBackground;

  static const Color sectionItemBackground = CupertinoColors.systemBackground;
  static const EdgeInsets sectionItemPadding = EdgeInsets.fromLTRB(0, 8, 0, 8);

  static const TextStyle sectionItemTitleTextStyle = TextStyle(
    fontSize: 16,
    color: CupertinoColors.black,
    overflow: TextOverflow.ellipsis,
  );
  static const TextStyle sectionItemSubtitleTextStyle = TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
    overflow: TextOverflow.fade,
  );
  static const TextStyle sectionItemAdditionalTextStyle = TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  //
  //  Chat Box
  //
  static const EdgeInsets messageItemMargin = EdgeInsets.fromLTRB(8, 4, 8, 4);
  static const TextStyle messageTimeTextStyle = TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
  );

  static const EdgeInsets messageSenderAvatarPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);

  static const EdgeInsets messageSenderNameMargin = EdgeInsets.all(2);
  static const TextStyle messageSenderNameTextStyle = TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
    overflow: TextOverflow.ellipsis,
  );

  static const EdgeInsets messageContentMargin = EdgeInsets.fromLTRB(2, 8, 2, 8);
  static const Color messageIsMineBackgroundColor = CupertinoColors.systemGreen;
  static const Color messageNotMineBackgroundColor = CupertinoColors.white;

  static const EdgeInsets textMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const EdgeInsets audioMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);

  static const EdgeInsets commandPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);
  static const Color commandBackgroundColor = CupertinoColors.lightBackgroundGray;
  static const TextStyle commandTextStyle = TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
  );
  static const Color inputTrayBackground = CupertinoColors.systemBackground;

}
