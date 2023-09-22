import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;

import '../client/constants.dart';
import '../models/chat.dart';

const String _kNameViewRefresh = 'NameViewRefresh';

/// NameView
class NameLabel extends StatefulWidget {
  const NameLabel(this.info, {super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final Conversation info;

  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// reload info
  Future<void> reload() async {
    await info.reloadData();
    await refresh();
  }

  /// refresh label
  Future<void> refresh() async {
    await lnc.NotificationCenter().postNotification(_kNameViewRefresh, this, {
      'ID': info.identifier,
    });
  }

  @override
  State<StatefulWidget> createState() => _NameState();

}

class _NameState extends State<NameLabel> implements lnc.Observer {
  _NameState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, _kNameViewRefresh);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    nc.removeObserver(this, _kNameViewRefresh);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == _kNameViewRefresh) {
      ID? identifier = info?['ID'];
      if (identifier == widget.info.identifier) {
        if (mounted) {
          setState(() {
            // refresh
          });
        }
      }
    } else if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = info?['ID'];
      if (identifier == widget.info.identifier) {
        if (mounted) {
          setState(() {
            // refresh
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Text(widget.info.name,
    style:              widget.style,
    strutStyle:         widget.strutStyle,
    textAlign:          widget.textAlign,
    textDirection:      widget.textDirection,
    locale:             widget.locale,
    softWrap:           widget.softWrap,
    overflow:           widget.overflow,
    textScaleFactor:    widget.textScaleFactor,
    maxLines:           widget.maxLines,
    semanticsLabel:     widget.semanticsLabel,
    textWidthBasis:     widget.textWidthBasis,
    textHeightBehavior: widget.textHeightBehavior,
    selectionColor:     widget.selectionColor,
  );

}
