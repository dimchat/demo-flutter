// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  static const EdgeInsets settingsSectionItemPadding = EdgeInsets.all(16);

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

  static const Color avatarDefaultColor = CupertinoColors.inactiveGray;

  //
  //  Icons
  //  ~~~~~
  //  https://api.flutter.dev/flutter/cupertino/CupertinoIcons-class.html#constants
  //  https://api.flutter.dev/flutter/material/Icons-class.html
  //

  static const IconData stationIcon = CupertinoIcons.cloud;
  static const IconData     ispIcon = CupertinoIcons.cloud_moon;
  static const IconData     botIcon = Icons.support_agent;
  static const IconData     icpIcon = Icons.room_service_outlined;
  static const IconData    userIcon = CupertinoIcons.person;
  static const IconData   groupIcon = CupertinoIcons.group;

  // Tabs
  static const IconData    chatsTabIcon = CupertinoIcons.chat_bubble_2;
  static const IconData contactsTabIcon = CupertinoIcons.group;
  static const IconData settingsTabIcon = CupertinoIcons.gear;

  // Chat Box
  static const IconData   chatDetailIcon = Icons.more_horiz;
  static const IconData      chatMicIcon = CupertinoIcons.mic;
  static const IconData chatKeyboardIcon = CupertinoIcons.keyboard;
  static const IconData chatFunctionIcon = Icons.add_circle_outline;
  static const IconData     chatSendIcon = Icons.send;
  // Audio
  static const IconData    waitAudioIcon = CupertinoIcons.cloud_download;
  static const IconData    playAudioIcon = CupertinoIcons.play;
  static const IconData playingAudioIcon = CupertinoIcons.volume_up;
  // Msg Status
  static const IconData   msgDefaultIcon = CupertinoIcons.ellipsis;
  static const IconData   msgWaitingIcon = CupertinoIcons.ellipsis;
  static const IconData      msgSentIcon = Icons.done;
  static const IconData  msgReceivedIcon = Icons.done_all;
  static const IconData       msgExpired = CupertinoIcons.refresh;

  // Contacts
  static const IconData searchIcon = CupertinoIcons.search;

  // Search
  static const IconData newFriendsIcon = CupertinoIcons.person_add;
  static const IconData groupChatsIcon = CupertinoIcons.person_2;

  // Settings
  static const IconData exportAccountIcon = Icons.account_balance_wallet_outlined;
  static const IconData    setNetworkIcon = CupertinoIcons.settings;
  static const IconData setWhitePaperIcon = CupertinoIcons.doc;
  static const IconData setOpenSourceIcon = Icons.code;
  static const IconData      setTermsIcon = CupertinoIcons.doc_checkmark;
  static const IconData      setAboutIcon = CupertinoIcons.info;

  // Relay Stations
  static const IconData refreshStationsIcon = Icons.forward_5;
  static const IconData  currentStationIcon = CupertinoIcons.cloud_upload_fill;
  static const IconData   chosenStationIcon = CupertinoIcons.cloud_fill;

  // Register
  static const IconData agreeIcon = CupertinoIcons.check_mark;

}
