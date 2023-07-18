import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;
import 'package:lnc/lnc.dart' show Log;

import '../client/constants.dart';
import '../client/shared.dart';
import '../common/protocol/name_card.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../network/image_view.dart';

import 'audio.dart';
import 'browser.dart';
import 'name_card.dart';
import 'preview.dart';
import 'styles.dart';


abstract class ContentViewUtils {

  static User? currentUser;

  static Color getBackgroundColor(BuildContext context, ID sender) =>
      sender == currentUser?.identifier
          ? Styles.messageIsMineBackgroundColor
          : Facade.of(context).colors.textMessageBackgroundColor;

  static Color getTextColor(BuildContext context, ID sender) =>
      sender == currentUser?.identifier
          ? CupertinoColors.black
          : Facade.of(context).colors.textMessageColor;

  /// return null if it's not a command
  ///        empty string ('') for ignored command
  static String? getCommandText(Content content, ID sender, ContactInfo chat) {
    String? text;
    DefaultMessageBuilder mb = DefaultMessageBuilder();
    if (mb.isCommand(content, sender)) {
      // check sender
      if (sender != chat.identifier) {
        // it's a command but not from my friend,
        // maybe it's sent by myself, or a member in group chat,
        // just ignore it to reduce noises.
        Log.warning('hide command from: $sender, $text');
        return '';
      }
      // check text
      text = mb.getText(content, sender);
      // TODO: hide text receipt?
    }
    return text;
  }

  static Widget getCommandLabel(BuildContext context, String text) => Column(
    children: [
      ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: Container(
          padding: Styles.commandPadding,
          color: Facade.of(context).colors.commandBackgroundColor,
          child: Text(text, style: Facade.of(context).styles.commandTextStyle),
        ),
      )
    ],
  );

  static Widget getNameLabel(BuildContext context, ID sender) => Container(
    margin: Styles.messageSenderNameMargin,
    constraints: const BoxConstraints(maxWidth: 256),
    child: _NameView(sender,
      style: Facade.of(context).styles.messageSenderNameTextStyle,
    ),
  );

  static Widget getTextContentView(BuildContext ctx, Content content, ID sender, {OnWebShare? onWebShare}) => Container(
    color: getBackgroundColor(ctx, sender),
    padding: Styles.textMessagePadding,
    // child: SelectableText(
    //   DefaultMessageBuilder().getText(content, sender),
    //   style: TextStyle(color: getTextColor(ctx, sender)),
    // ),
    child: SelectableLinkify(
      text: DefaultMessageBuilder().getText(content, sender),
      style: TextStyle(color: getTextColor(ctx, sender)),
      linkStyle: const TextStyle(decoration: TextDecoration.none,),
      // options: const LinkifyOptions(humanize: false),
      linkifiers: const [UrlLinkifier(),],
      contextMenuBuilder: (context, state) => AdaptiveTextSelectionToolbar.editableText(
        editableTextState: state,
      ),
      onOpen: (link) => Browser.open(ctx, url: link.url, onShare: onWebShare,),
    ),
  );

  static Widget getAudioContentView(BuildContext ctx, AudioContent content, ID sender) =>
      AudioContentView(content,
        textColor: getTextColor(ctx, sender),
        backgroundColor: getBackgroundColor(ctx, sender),
      );

  // TODO:
  static Widget getVideoContentView(BuildContext ctx, VideoContent content, ID sender) =>
      Text('Movie[${content.filename}]: ${content.url}');

  static Widget getImageContentView(BuildContext ctx,
      ImageContent content, ID sender, List<InstantMessage> messages,
      {GestureTapCallback? onTap, GestureLongPressCallback? onLongPress}) =>
      ImageViewFactory().fromContent(content,
        onTap: onTap ?? () => previewImageContent(ctx, content, messages),
        onLongPress: onLongPress,
      );

  static Widget getPageContentView(BuildContext ctx, PageContent content, ID sender,
      {GestureTapCallback? onTap, OnWebShare? onWebShare}) =>
      PageContentView(content: content,
        onTap: onTap ?? () => Browser.open(ctx, url: content.url, onShare: onWebShare,),
      );

  static Widget getNameCardView(BuildContext ctx, NameCard content,
      {GestureTapCallback? onTap}) =>
      NameCardView(content: content,
        onTap: onTap,
      );

}

/// NameView
class _NameView extends StatefulWidget {
  const _NameView(this.identifier, {required this.style});

  final ID identifier;
  final TextStyle? style;

  @override
  State<StatefulWidget> createState() => _NameState();

}

class _NameState extends State<_NameView> implements lnc.Observer {
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
  Widget build(BuildContext context) => Text('$_name', style: widget.style);

}
