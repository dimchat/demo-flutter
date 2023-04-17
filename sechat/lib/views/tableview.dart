import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'styles.dart';

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
