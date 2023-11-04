import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;

import '../common/constants.dart';
import '../models/chat.dart';


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

  @override
  State<StatefulWidget> createState() => _NameState();

}

class _NameState extends State<NameLabel> implements lnc.Observer {
  _NameState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kRemarkUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kRemarkUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = info?['ID'];
      if (identifier == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kRemarkUpdated) {
      ID? identifier = info?['contact'];
      if (identifier == widget.info.identifier) {
        await _reload();
      }
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        // refresh
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Text(widget.info.title,
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
