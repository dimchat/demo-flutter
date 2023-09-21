import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/shared.dart';

/// NameView
class NameLabel extends StatefulWidget {
  const NameLabel(this.identifier, {super.key,
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

  final ID identifier;

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
  }

  String? _name;

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    assert(name == NotificationNames.kDocumentUpdated, 'notification error: $notification');
    ID? identifier = info?['ID'];
    if (identifier == null) {
      Log.error('notification error: $notification');
    } else if (identifier == widget.identifier) {
      _reload();
    }
  }

  void _reload() {
    GlobalVariable shared = GlobalVariable();
    shared.facebook.getName(widget.identifier).then((name) {
      if (mounted) {
        setState(() {
          _name = name;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _name = widget.identifier.toString();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Text('$_name',
    style: widget.style,
    strutStyle: widget.strutStyle,
    textAlign: widget.textAlign,
    textDirection: widget.textDirection,
    locale: widget.locale,
    softWrap: widget.softWrap,
    overflow: widget.overflow,
    textScaleFactor: widget.textScaleFactor,
    maxLines: widget.maxLines,
    semanticsLabel: widget.semanticsLabel,
    textWidthBasis: widget.textWidthBasis,
    textHeightBehavior: widget.textHeightBehavior,
    selectionColor: widget.selectionColor,
  );

}
