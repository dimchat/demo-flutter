import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'brightness.dart';

const Color tarsierLogoBackgroundColor = Color(0xFF33C0F3);


abstract class ThemeColors {

  Color get logoBackgroundColor => tarsierLogoBackgroundColor;

  Color get avatarColor => tarsierLogoBackgroundColor;
  Color get avatarDefaultColor => CupertinoColors.inactiveGray;

  // Color get tabColor => CupertinoColors.black;
  Color get activeTabColor => CupertinoColors.systemBlue;

  Color get scaffoldBackgroundColor;
  Color get appBardBackgroundColor;

  Color get inputTrayBackgroundColor;

  Color get sectionHeaderBackgroundColor;
  Color get sectionFooterBackgroundColor;
  Color get sectionItemBackgroundColor;
  Color get sectionItemDividerColor;

  Color get buttonTextColor => CupertinoColors.white;
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

  //
  //  Common
  //
  Color get commandBackgroundColor;
  Color get messageIsMineBackgroundColor;

  //
  //  Text Style
  //
  Color get titleTextColor;

  Color get sectionHeaderTextColor => CupertinoColors.systemGrey;
  Color get sectionFooterTextColor => CupertinoColors.systemGrey;
  Color get sectionItemTitleTextColor;
  Color get sectionItemSubtitleTextColor => CupertinoColors.systemGrey;
  Color get sectionItemAdditionalTextColor => CupertinoColors.systemGrey;

  Color get identifierTextColor => Colors.teal;
  Color get messageSenderNameTextColor => CupertinoColors.systemGrey;
  Color get messageTimeTextColor => CupertinoColors.systemGrey;
  Color get commandTextColor => CupertinoColors.systemGrey;
  Color get pageTitleTextColor;
  Color get pageDescTextColor;

  //
  //  Text Field Style
  //
  Color get textFieldColor;
  Color get textFieldDecorationColor;
  Color get textFieldDecorationBorderColor;

  //
  //  Colors based on Brightness
  //

  /// Current colors
  static ThemeColors get current =>
      BrightnessDataSource().isDarkMode ? _dark : _light;

  static final ThemeColors _light = _LightThemeColors();
  static final ThemeColors _dark = _DarkThemeColors();

}

class _LightThemeColors extends ThemeColors {

  @override
  Color get scaffoldBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get appBardBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get inputTrayBackgroundColor => CupertinoColors.white;

  @override
  Color get sectionHeaderBackgroundColor => Colors.white70;

  @override
  Color get sectionFooterBackgroundColor => Colors.white70;

  @override
  Color get sectionItemBackgroundColor => CupertinoColors.systemBackground;

  @override
  Color get sectionItemDividerColor => const Color(0xFFEEEEEE);

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
  //  Common
  //
  @override
  Color get commandBackgroundColor => CupertinoColors.lightBackgroundGray;

  @override
  Color get messageIsMineBackgroundColor => const Color(0xFFA9E879);

  //
  //  Web Page Message
  //
  @override
  Color get pageMessageBackgroundColor => CupertinoColors.white;

  @override
  Color get pageMessageColor => CupertinoColors.black;

  //
  //  Text Style
  //
  @override
  Color get titleTextColor => CupertinoColors.black;

  @override
  Color get sectionItemTitleTextColor => CupertinoColors.black;

  @override
  Color get pageTitleTextColor => CupertinoColors.black;

  @override
  Color get pageDescTextColor => CupertinoColors.systemGrey;

  //
  //  Text Field Style
  //
  @override
  Color get textFieldColor => CupertinoColors.black;

  @override
  Color get textFieldDecorationColor => CupertinoColors.white;

  @override
  Color get textFieldDecorationBorderColor => CupertinoColors.lightBackgroundGray;

}

class _DarkThemeColors extends ThemeColors {

  @override
  Color get scaffoldBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get appBardBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get inputTrayBackgroundColor => CupertinoColors.systemFill;

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
  Color get textMessageBackgroundColor => const Color(0xFF303030);

  @override
  Color get textMessageColor => CupertinoColors.white;

  //
  //  Web Page Message
  //
  @override
  Color get pageMessageBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get pageMessageColor => CupertinoColors.white;

  //
  //  Common
  //
  @override
  Color get commandBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get messageIsMineBackgroundColor => const Color(0xFF58B169);

  //
  //  Text Style
  //
  @override
  Color get titleTextColor => CupertinoColors.white;

  @override
  Color get sectionItemTitleTextColor => CupertinoColors.white;

  @override
  Color get pageTitleTextColor => CupertinoColors.white;

  @override
  Color get pageDescTextColor => CupertinoColors.systemGrey;

  //
  //  Text Field Style
  //
  @override
  Color get textFieldColor => CupertinoColors.white;

  @override
  Color get textFieldDecorationColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get textFieldDecorationBorderColor => CupertinoColors.systemGrey;

}
