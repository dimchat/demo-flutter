import 'package:flutter/material.dart';

import 'colors.dart';


abstract class Styles {

  static ThemeColors get colors => ThemeColors.current;

  static TextStyle get buttonTextStyle => TextStyle(
    color: colors.buttonTextColor,
    fontWeight: FontWeight.bold,
  );

  //
  //  Text Style
  //

  static TextStyle get titleTextStyle => TextStyle(
    color: colors.titleTextColor,
  );

  static TextStyle get sectionHeaderTextStyle => TextStyle(
    fontSize: 12,
    color: colors.sectionHeaderTextColor,
    decoration: TextDecoration.none,
  );

  static TextStyle get sectionFooterTextStyle => TextStyle(
    fontSize: 10,
    color: colors.sectionFooterTextColor,
    decoration: TextDecoration.none,
  );

  static TextStyle get sectionItemTitleTextStyle => TextStyle(
    fontSize: 16,
    color: colors.sectionItemTitleTextColor,
    overflow: TextOverflow.ellipsis,
  );

  static TextStyle get sectionItemSubtitleTextStyle => TextStyle(
    fontSize: 10,
    color: colors.sectionItemSubtitleTextColor,
    overflow: TextOverflow.fade,
  );

  static TextStyle get sectionItemAdditionalTextStyle => TextStyle(
    fontSize: 12,
    color: colors.sectionItemAdditionalTextColor,
  );

  static TextStyle get identifierTextStyle => TextStyle(
    fontSize: 12,
    color: colors.identifierTextColor,
  );

  static TextStyle get messageSenderNameTextStyle => TextStyle(
    fontSize: 12,
    color: colors.messageSenderNameTextColor,
    overflow: TextOverflow.ellipsis,
  );

  static TextStyle get messageTimeTextStyle => TextStyle(
    fontSize: 10,
    color: colors.messageTimeTextColor,
  );

  static TextStyle get commandTextStyle => TextStyle(
    fontSize: 10,
    color: colors.commandTextColor,
  );

  static TextStyle get pageTitleTextStyle => TextStyle(
    fontSize: 14,
    color: colors.pageTitleTextColor,
    overflow: TextOverflow.ellipsis,
  );

  static TextStyle get pageDescTextStyle => TextStyle(
    fontSize: 10,
    color: colors.pageDescTextColor,
    overflow: TextOverflow.ellipsis,
  );

  static TextStyle get translatorTextStyle => TextStyle(
    fontSize: 10,
    color: colors.commandTextColor,
    decoration: TextDecoration.none,
  );

  //
  //  Text Field Style
  //
  static TextStyle get textFieldStyle => TextStyle(
    height: 1.6,
    color: colors.textFieldColor,
  );

  static BoxDecoration get textFieldDecoration => BoxDecoration(
    color: colors.textFieldDecorationColor,
    border: Border.all(
      color: colors.textFieldDecorationBorderColor,
      style: BorderStyle.solid,
      width: 1,
    ),
    borderRadius: BorderRadius.circular(8),
  );

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

  static const EdgeInsets messageContentMargin = EdgeInsets.fromLTRB(2, 2, 2, 2);

  static const EdgeInsets textMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const EdgeInsets audioMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);

  static const EdgeInsets pageMessagePadding = EdgeInsets.fromLTRB(12, 8, 8, 8);

  static const EdgeInsets commandPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);

  //
  //  Live Stream
  //
  static const TextStyle liveGroupStyle = TextStyle(
    color: Colors.yellow,
    fontSize: 24,
    decoration: TextDecoration.none,
  );

  static const TextStyle liveChannelStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    decoration: TextDecoration.none,
  );

  static const TextStyle livePlayingStyle = TextStyle(
    color: Colors.blue,
    fontSize: 16,
    decoration: TextDecoration.none,
  );

}
