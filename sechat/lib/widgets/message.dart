import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart' as lnc;

import '../client/constants.dart';
import '../client/http/image_view.dart';
import '../client/shared.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../views/styles.dart';
import 'audio.dart';
import 'preview.dart';

abstract class ContentViewUtils {

  static User? currentUser;

  static Color getBackgroundColor(ID sender) =>
      sender == currentUser?.identifier
          ? Styles.messageIsMineBackgroundColor
          : Styles.messageNotMineBackgroundColor;

  /// return null if it's not a command
  ///        empty string ('') for ignored command
  static String? getCommandText(Content content, ID sender, ContactInfo chat) {
    String? text;
    DefaultMessageBuilder mb = DefaultMessageBuilder();
    if (mb.isCommand(content)) {
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
      if (text.startsWith('Document received: ')) {
        // // hide it
        // Log.warning('hide command from: $sender, $text');
        // text = '';
      }
    }
    return text;
  }

  static Widget getCommandLabel(String text) => Column(
    children: [
      ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: Container(
          padding: Styles.commandPadding,
          color: Styles.commandBackgroundColor,
          child: Text(text, style: Styles.commandTextStyle),
        ),
      )
    ],
  );

  static Widget getNameLabel(ID sender) => Container(
    margin: Styles.messageSenderNameMargin,
    constraints: const BoxConstraints(maxWidth: 256),
    child: _NameView(sender, style: Styles.messageSenderNameTextStyle),
  );

  static Widget getTextContentView(Content content, ID sender) => Container(
    color: getBackgroundColor(sender),
    padding: Styles.textMessagePadding,
    child: SelectableText('${content["text"]}'),
  );

  static Widget getAudioContentView(AudioContent content, ID sender) =>
      AudioContentView(content, color: getBackgroundColor(sender));

  // TODO:
  static Widget getVideoContentView(VideoContent content, ID sender) =>
      Text('Movie[${content.filename}]: ${content.url}');

  static Widget getImageContentView(BuildContext ctx,
      ImageContent content, ID sender, List<InstantMessage> messages) =>
      ImageViewFactory().fromContent(content,
          onTap: () => previewImageContent(ctx, content, messages));

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
