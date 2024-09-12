import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import '../models/chat.dart';
import '../models/chat_contact.dart';
import '../models/message.dart';
import '../pnf/auto_image.dart';
import '../pnf/net_video.dart';
import '../pnf/net_voice.dart';
import '../ui/styles.dart';
import '../video/playing.dart';

import 'browser.dart';
import 'name_card.dart';
import 'text.dart';


abstract class ContentViewUtils {

  static User? currentUser;

  static Color getBackgroundColor(ID sender) =>
      sender == currentUser?.identifier
          ? Styles.colors.messageIsMineBackgroundColor
          : Styles.colors.textMessageBackgroundColor;

  static Color getTextColor(ID sender) =>
      sender == currentUser?.identifier
          ? CupertinoColors.black
          : Styles.colors.textMessageColor;

  /// return null if it's not a command
  ///        empty string ('') for ignored command
  static String? getCommandText(Content content, ID sender, Conversation chat) {
    String? text;
    DefaultMessageBuilder mb = DefaultMessageBuilder();
    if (mb.isCommand(content, sender)) {
      // check sender
      if (sender != chat.identifier) {
        // it's a command but not from my friend,
        // maybe it's sent by myself, or a member in group chat,
        // just ignore it to reduce noises.
        Log.warning('hide command from: $sender, $text');
        if (mb.isHiddenContent(content, sender)) {
          return '';
        }
      }
      // check text
      text = mb.getText(content, sender);
      // TODO: hide text receipt?
    }
    return text;
  }

  static Widget getCommandLabel(BuildContext context, String text) => Column(
    children: [
      const SizedBox(height: 4,),
      ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Container(
          padding: Styles.commandPadding,
          color: Styles.colors.commandBackgroundColor,
          child: Text(text, style: Styles.commandTextStyle),
        ),
      )
    ],
  );

  static Widget getNameLabel(BuildContext context, ID sender) => Container(
    margin: Styles.messageSenderNameMargin,
    constraints: const BoxConstraints(maxWidth: 256),
    child: ContactInfo.fromID(sender)!.getNameLabel(
      style: Styles.messageSenderNameTextStyle,
    ),
  );

  static Widget getTextContentView(Content content, ID sender, {
    required GestureTapCallback? onDoubleTap,
    required GestureLongPressCallback? onLongPress,
    required OnWebShare? onWebShare,
    required OnVideoShare? onVideoShare,
  }) {
    bool mine = sender == currentUser?.identifier;
    var format = content.getString('format', null);
    bool plain = mine || format != 'markdown';
    String text = DefaultMessageBuilder().getText(content, sender);
    Widget textView = plain
        ? SelectableText(text, style: TextStyle(color: getTextColor(sender)),)
        : RichTextView(sender: sender, text: text, onWebShare: onWebShare, onVideoShare: onVideoShare,);
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        color: getBackgroundColor(sender),
        padding: Styles.textMessagePadding,
        child: textView,
      ),
    );
  }

  static Widget getAudioContentView(AudioContent content, ID sender, {
    required GestureLongPressCallback? onLongPress,
  }) {
    Widget view = NetworkAudioFactory().getAudioView(content,
      color: getTextColor(sender),
      backgroundColor: getBackgroundColor(sender),
    );
    if (onLongPress == null) {
      return view;
    }
    return GestureDetector(
      onLongPress: onLongPress,
      child: view,
    );
  }

  static Widget getVideoContentView(VideoContent content, ID sender, {
    required GestureLongPressCallback? onLongPress,
    required OnVideoShare? onVideoShare,
  }) {
    Widget view = NetworkVideoFactory().getVideoView(content, onVideoShare: onVideoShare);
    if (onLongPress == null) {
      return view;
    }
    return GestureDetector(
      onLongPress: onLongPress,
      child: view,
    );
  }

  static Widget getImageContentView(ImageContent content, ID sender, {
    required GestureTapCallback? onTap,
    required GestureLongPressCallback? onLongPress,
  }) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: NetworkImageFactory().getImageView(PortableNetworkFile.parse(content)!),
  );

  static Widget getPageContentView(PageContent content, ID sender, {
    required GestureTapCallback? onTap,
    required GestureLongPressCallback? onLongPress,
  }) => PageContentView(content: content,
    onTap: onTap,
    onLongPress: onLongPress,
  );

  static Widget getNameCardView(NameCard content, {
    required GestureTapCallback? onTap,
    required GestureLongPressCallback? onLongPress,
  }) => NameCardView(content: content,
    onTap: onTap,
    onLongPress: onLongPress,
  );

}
