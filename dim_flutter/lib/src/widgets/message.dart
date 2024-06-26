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
import 'browse_html.dart';
import 'name_card.dart';
import 'text.dart';


abstract class ContentViewUtils {

  static User? currentUser;

  static Color getBackgroundColor(BuildContext context, ID sender) =>
      sender == currentUser?.identifier
          ? Styles.colors.messageIsMineBackgroundColor
          : Styles.colors.textMessageBackgroundColor;

  static Color getTextColor(BuildContext context, ID sender) =>
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

  static Widget getTextContentView(BuildContext ctx, Content content, ID sender, {
    required OnWebShare? onWebShare,
    required OnVideoShare? onVideoShare,
  }) {
    String text = DefaultMessageBuilder().getText(content, sender);
    bool mine = sender == currentUser?.identifier;
    var format = content.getString('format', null);
    bool plain = mine || format != 'markdown';
    Widget textView = plain
        ? SelectableText(text, style: TextStyle(color: getTextColor(ctx, sender)),)
        : RichTextView(sender: sender, text: text, onWebShare: onWebShare, onVideoShare: onVideoShare,);
    return GestureDetector(
      child: Container(
        color: getBackgroundColor(ctx, sender),
        padding: Styles.textMessagePadding,
        child: textView,
      ),
      onDoubleTap: () => TextPreviewPage.open(ctx,
        text: text, sender: sender,
        onWebShare: onWebShare,
        onVideoShare: onVideoShare,
        previewing: plain,
      ),
    );
  }

  static Widget getAudioContentView(BuildContext ctx, AudioContent content, ID sender, {
    GestureLongPressCallback? onLongPress,
  }) {
    Widget view = NetworkAudioFactory().getAudioView(content,
      color: getTextColor(ctx, sender),
      backgroundColor: getBackgroundColor(ctx, sender),
    );
    if (onLongPress == null) {
      return view;
    }
    return GestureDetector(
      onLongPress: onLongPress,
      child: view,
    );
  }

  static Widget getVideoContentView(BuildContext ctx, VideoContent content, ID sender, {
    GestureLongPressCallback? onLongPress, OnVideoShare? onVideoShare,
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

  static Widget getImageContentView(BuildContext ctx, ImageContent content, ID sender, List<InstantMessage> messages, {
    GestureTapCallback? onTap, GestureLongPressCallback? onLongPress,
  }) => GestureDetector(
    onTap: onTap ?? () => previewImageContent(ctx, content, messages),
    onLongPress: onLongPress,
    child: NetworkImageFactory().getImageView(PortableNetworkFile.parse(content)!),
  );

  static Widget getPageContentView(BuildContext ctx, PageContent content, ID sender, {
    GestureTapCallback? onTap, GestureLongPressCallback? onLongPress, OnWebShare? onWebShare,
  }) => PageContentView(content: content,
    onTap: onTap ?? () => Browser.open(ctx,
      url: HtmlUri.getUriString(content),
      onShare: onWebShare,
    ),
    onLongPress: onLongPress,
  );

  static Widget getNameCardView(BuildContext ctx, NameCard content, {
    GestureTapCallback? onTap, GestureLongPressCallback? onLongPress,
  }) => NameCardView(content: content,
    onTap: onTap,
    onLongPress: onLongPress,
  );

}
