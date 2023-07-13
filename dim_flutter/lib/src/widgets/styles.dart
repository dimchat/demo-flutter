// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Colors
abstract class ThemeColors {

  Color get logoBackgroundColor => Styles.logoBackgroundColor;

  Color get scaffoldBackgroundColor;
  Color get appBardBackgroundColor;

  Color get inputTrayBackgroundColor;
  Color get commandBackgroundColor;

  Color get sectionHeaderBackgroundColor;
  Color get sectionFooterBackgroundColor;
  Color get sectionItemBackgroundColor;
  Color get sectionItemDividerColor;

  Color get normalButtonColor => CupertinoColors.systemBlue;
  Color get importantButtonColor => CupertinoColors.systemOrange;
  Color get criticalButtonColor => CupertinoColors.systemRed;

  Color get primaryTextColor;
  Color get secondaryTextColor;
  Color get tertiaryTextColor;

  //
  //  Mnemonic Codes
  //
  Color get tileBackgroundColor;
  Color get tileInvisibleColor;
  Color get tileColor;
  Color get tileBadgeColor;
  Color get tileOrderColor;

  //
  //  Audio Recorder
  //
  Color get recorderTextColor;
  Color get recorderBackgroundColor;
  Color get recordingBackgroundColor;
  Color get cancelRecordingBackgroundColor;

  //
  //  Text Message
  //
  Color get textMessageColor;
  Color get textMessageBackgroundColor;

  //
  //  Web Page Message
  //
  Color get pageMessageColor;
  Color get pageMessageBackgroundColor;

}

class _LightThemeColors extends ThemeColors {
  factory _LightThemeColors() => _instance;
  static final _LightThemeColors _instance = _LightThemeColors._internal();
  _LightThemeColors._internal();

  @override
  Color get scaffoldBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get appBardBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get inputTrayBackgroundColor => CupertinoColors.white;

  @override
  Color get commandBackgroundColor => CupertinoColors.lightBackgroundGray;

  @override
  Color get sectionHeaderBackgroundColor => Colors.white70;

  @override
  Color get sectionFooterBackgroundColor => Colors.white70;

  @override
  Color get sectionItemBackgroundColor => CupertinoColors.systemBackground;

  @override
  Color get sectionItemDividerColor => CupertinoColors.secondarySystemBackground;

  @override
  Color get primaryTextColor => CupertinoColors.black;

  @override
  Color get secondaryTextColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get tertiaryTextColor => CupertinoColors.systemGrey;

  //
  //  Mnemonic Codes
  //
  @override
  Color get tileBackgroundColor => CupertinoColors.lightBackgroundGray;

  @override
  Color get tileInvisibleColor => CupertinoColors.systemGrey;

  @override
  Color get tileColor => CupertinoColors.black;

  @override
  Color get tileBadgeColor => CupertinoColors.white;

  @override
  Color get tileOrderColor => CupertinoColors.systemGrey;

  //
  //  Audio Recorder
  //
  @override
  Color get recorderTextColor => CupertinoColors.black;

  @override
  Color get recorderBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get recordingBackgroundColor => Colors.green.shade100;

  @override
  Color get cancelRecordingBackgroundColor => Colors.yellow.shade100;

  //
  //  Text Message
  //
  @override
  Color get textMessageBackgroundColor => CupertinoColors.white;

  @override
  Color get textMessageColor => CupertinoColors.black;

  //
  //  Web Page Message
  //
  @override
  Color get pageMessageBackgroundColor => CupertinoColors.white;

  @override
  Color get pageMessageColor => CupertinoColors.black;

}

class _DarkThemeColors extends ThemeColors {
  factory _DarkThemeColors() => _instance;
  static final _DarkThemeColors _instance = _DarkThemeColors._internal();
  _DarkThemeColors._internal();

  @override
  Color get scaffoldBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get appBardBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get inputTrayBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get commandBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get sectionHeaderBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get sectionFooterBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get sectionItemBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get sectionItemDividerColor => const Color(0xFF222222);

  @override
  Color get primaryTextColor => CupertinoColors.white;

  @override
  Color get secondaryTextColor => CupertinoColors.lightBackgroundGray;

  @override
  Color get tertiaryTextColor => CupertinoColors.systemGrey;

  //
  //  Mnemonic Codes
  //
  @override
  Color get tileBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get tileInvisibleColor => CupertinoColors.systemGrey;

  @override
  Color get tileColor => CupertinoColors.white;

  @override
  Color get tileBadgeColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get tileOrderColor => CupertinoColors.systemGrey;

  //
  //  Audio Recorder
  //
  @override
  Color get recorderTextColor => CupertinoColors.white;

  @override
  Color get recorderBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get recordingBackgroundColor => CupertinoColors.systemGrey;

  @override
  Color get cancelRecordingBackgroundColor => CupertinoColors.darkBackgroundGray;

  //
  //  Text Message
  //
  @override
  Color get textMessageBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get textMessageColor => CupertinoColors.white;

  //
  //  Web Page Message
  //
  @override
  Color get pageMessageBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get pageMessageColor => CupertinoColors.white;

}

/// Styles
abstract class ThemeStyles {

  TextStyle get titleTextStyle;

  TextStyle get sectionHeaderTextStyle;
  TextStyle get sectionFooterTextStyle;
  TextStyle get sectionItemTitleTextStyle;
  TextStyle get sectionItemSubtitleTextStyle;
  TextStyle get sectionItemAdditionalTextStyle;

  TextStyle get textFieldStyle;
  BoxDecoration get textFieldDecoration;

  TextStyle get buttonStyle => const TextStyle(
    color: CupertinoColors.white,
    fontWeight: FontWeight.bold,
  );

  TextStyle get commandTextStyle;

  TextStyle get messageTimeTextStyle;

  TextStyle get messageSenderNameTextStyle => const TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
    overflow: TextOverflow.ellipsis,
  );

  TextStyle get identifierTextStyle => const TextStyle(
    fontSize: 12,
    color: Colors.teal,
  );

  //
  //  Web Page Message
  //
  TextStyle get pageTitleTextStyle;
  TextStyle get pageDescTextStyle;

}

class _LightThemeStyles extends ThemeStyles {
  factory _LightThemeStyles() => _instance;
  static final _LightThemeStyles _instance = _LightThemeStyles._internal();
  _LightThemeStyles._internal();

  @override
  TextStyle get titleTextStyle => const TextStyle(
    color: CupertinoColors.black,
  );

  @override
  TextStyle get sectionHeaderTextStyle => const TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get sectionFooterTextStyle => const TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get sectionItemTitleTextStyle => const TextStyle(
    fontSize: 16,
    color: CupertinoColors.black,
    overflow: TextOverflow.ellipsis,
  );

  @override
  TextStyle get sectionItemSubtitleTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
    overflow: TextOverflow.fade,
  );

  @override
  TextStyle get sectionItemAdditionalTextStyle => const TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get textFieldStyle => const TextStyle(
    height: 1.6,
    color: CupertinoColors.black,
  );

  @override
  BoxDecoration get textFieldDecoration => BoxDecoration(
    color: CupertinoColors.white,
    border: Border.all(
      color: CupertinoColors.lightBackgroundGray,
      style: BorderStyle.solid,
      width: 1,
    ),
    borderRadius: BorderRadius.circular(8),
  );

  @override
  TextStyle get commandTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get messageTimeTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
  );

  //
  //  Web Page Message
  //

  @override
  TextStyle get pageTitleTextStyle => const TextStyle(
    fontSize: 14,
    color: CupertinoColors.black,
    overflow: TextOverflow.ellipsis,
  );

  @override
  TextStyle get pageDescTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
    overflow: TextOverflow.ellipsis,
  );

}

class _DarkThemeStyles extends ThemeStyles {
  factory _DarkThemeStyles() => _instance;
  static final _DarkThemeStyles _instance = _DarkThemeStyles._internal();
  _DarkThemeStyles._internal();

  @override
  TextStyle get titleTextStyle => const TextStyle(
    color: CupertinoColors.white,
  );

  @override
  TextStyle get sectionHeaderTextStyle => const TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get sectionFooterTextStyle => const TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get sectionItemTitleTextStyle => const TextStyle(
    fontSize: 16,
    color: CupertinoColors.white,
    overflow: TextOverflow.ellipsis,
  );

  @override
  TextStyle get sectionItemSubtitleTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
    overflow: TextOverflow.fade,
  );

  @override
  TextStyle get sectionItemAdditionalTextStyle => const TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get textFieldStyle => const TextStyle(
    height: 1.6,
    color: CupertinoColors.white,
  );

  @override
  BoxDecoration get textFieldDecoration => BoxDecoration(
    color: CupertinoColors.darkBackgroundGray,
    border: Border.all(
      color: CupertinoColors.systemGrey,
      style: BorderStyle.solid,
      width: 1,
    ),
    borderRadius: BorderRadius.circular(8),
  );

  @override
  TextStyle get commandTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
  );

  @override
  TextStyle get messageTimeTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
  );

  //
  //  Web Page Message
  //

  @override
  TextStyle get pageTitleTextStyle => const TextStyle(
    fontSize: 14,
    color: CupertinoColors.white,
    overflow: TextOverflow.ellipsis,
  );

  @override
  TextStyle get pageDescTextStyle => const TextStyle(
    fontSize: 10,
    color: CupertinoColors.systemGrey,
    overflow: TextOverflow.ellipsis,
  );

}

/// Theme
class Facade {
  Facade(this.context);

  final BuildContext context;

  static Facade of(BuildContext ctx) => Facade(ctx);

  Brightness get brightness => Theme.of(context).brightness;
  // Brightness get brightness => Brightness.dark;

  ThemeColors get colors =>
      brightness == Brightness.dark ? _DarkThemeColors() : _LightThemeColors();

  ThemeStyles get styles =>
      brightness == Brightness.dark ? _DarkThemeStyles() : _LightThemeStyles();

}

abstract class Styles {

  static const Color logoBackgroundColor = Color(0xFF33C0F3);

  //
  //  Navigation
  //
  static const double navigationBarIconSize = 16;

  //
  //  Section
  //
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.fromLTRB(16, 4, 16, 4);
  static const EdgeInsets sectionFooterPadding = EdgeInsets.fromLTRB(16, 4, 16, 4);

  static const EdgeInsets sectionItemPadding = EdgeInsets.fromLTRB(0, 8, 0, 8);

  static const EdgeInsets settingsSectionItemPadding = EdgeInsets.all(16);

  //
  //  Chat Box
  //
  static const EdgeInsets messageItemMargin = EdgeInsets.fromLTRB(8, 4, 8, 4);

  static const EdgeInsets messageSenderAvatarPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);

  static const EdgeInsets messageSenderNameMargin = EdgeInsets.all(2);

  static const EdgeInsets messageContentMargin = EdgeInsets.fromLTRB(2, 8, 2, 8);
  static const Color messageIsMineBackgroundColor = CupertinoColors.systemGreen;
  // static const Color messageNotMineBackgroundColor = CupertinoColors.systemFill;

  static const Color pageContentBackgroundColor = CupertinoColors.systemGreen;

  static const EdgeInsets textMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const EdgeInsets audioMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);

  static const EdgeInsets pageMessagePadding = EdgeInsets.fromLTRB(12, 8, 8, 8);

  static const EdgeInsets commandPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);

  static const Color avatarColor = logoBackgroundColor;
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
  static const IconData   msgExpiredIcon = CupertinoIcons.refresh;

  static const IconData      webpageIcon = CupertinoIcons.link;

  // Search
  static const IconData searchIcon = CupertinoIcons.search;

  // Contacts
  static const IconData newFriendsIcon = CupertinoIcons.person_add;
  static const IconData  blockListIcon = CupertinoIcons.person_crop_square_fill;
  static const IconData   muteListIcon = CupertinoIcons.app_badge;
  static const IconData groupChatsIcon = CupertinoIcons.person_2;

  static const IconData  addFriendIcon = CupertinoIcons.person_add;
  static const IconData    sendMsgIcon = CupertinoIcons.chat_bubble;
  static const IconData  clearChatIcon = CupertinoIcons.delete;
  static const IconData     deleteIcon = CupertinoIcons.delete;

  // Settings
  static const IconData exportAccountIcon = CupertinoIcons.lock_shield;
  // static const IconData exportAccountIcon = Icons.vpn_key_outlined;
  // static const IconData exportAccountIcon = Icons.account_balance_wallet_outlined;
  static const IconData    setNetworkIcon = CupertinoIcons.cloud;
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

  static const IconData updateDocIcon = CupertinoIcons.cloud_upload;

}
