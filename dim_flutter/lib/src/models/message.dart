import 'package:dim_client/dim_client.dart';

import 'contact.dart';

abstract class MessageBuilder {

  // protected
  String getName(ID identifier);

  /// Check whether this message content should be a command
  bool isCommand(Content content) {
    if (content is Command) {
      return true;
    }
    String? text = content['text'];
    if (text == null) {
      // unknown content
    } else if (text.startsWith('Document not accept')) {
      // take it as a receipt command
      return true;
    } else if (text.startsWith('Document not change')) {
      // take it as a receipt command
      return true;
    } else if (text.startsWith('Document receive')) {
      // take it as a receipt command
      return true;
    }
    // TODO: other situations?
    return false;
  }

  String getText(Content content, ID sender) {
    if (content is Command) {
      return _getCommandText(content, sender);
    }
    String? text = content['text'];
    if (text == null) {
      // unknown content
    } else if (text.startsWith('Document not accept')) {
      String sub = text.substring('Document not accepted: '.length);
      text = _replaceName(text, sub);
      return text;
    } else if (text.startsWith('Document not change')) {
      String sub = text.substring('Document not changed: '.length);
      text = _replaceName(text, sub);
      return text;
    } else if (text.startsWith('Document receive')) {
      String sub = text.substring('Document received: '.length);
      text = _replaceName(text, sub);
      return text;
    }
    return _getContentText(content);
  }

  String _replaceName(String text, String sub) {
    ID? identifier = ID.parse(sub);
    if (identifier == null) {
      return text;
    }
    String name = getName(identifier);
    if (name.isEmpty) {
      return text;
    }
    return text.replaceAll(sub, name);
  }

  String _getContentText(Content content) {
    String? text = content['text'];
    if (text != null) {
      return text;
    }
    if (content is TextContent) {
      return content.text;
    } else if (content is FileContent) {
      // File: Image, Audio, Video
      if (content is ImageContent) {
        text = '[Image:${content.filename}]';
      } else if (content is AudioContent) {
        text = '[Voice:${content.filename}]';
      } else if (content is VideoContent) {
        text = '[Movie:${content.filename}]';
      } else {
        text = '[File:${content.filename}]';
      }
    } else if (content is PageContent) {
      text = '[URL:${content.url}]';
    } else {
      text = "Current version doesn't support this message type: ${content.type}.";
    }
    // store message text
    content['text'] = text;
    return text;
  }

  String _getCommandText(Command content, ID sender) {
    String? text = content['text'];
    if (text != null) {
      return text;
    }
    if (content is GroupCommand) {
      text = _getGroupCommandText(content, sender);
    // } else if (content is HistoryCommand) {
    //   // TODO: process history command
    } else if (content is LoginCommand) {
      text = _getLoginCommandText(content, sender);
    } else {
      text = "Current version doesn't support this command: ${content.cmd}.";
    }
    // store message text
    content['text'] = text;
    return text;
  }

  //-------- System commands

  String _getLoginCommandText(LoginCommand content, ID sender) {
    ID identifier = content.identifier;
    String name = getName(identifier);
    var station = content.station;
    return '$name login: $station';
  }

  //...

  //-------- Group Commands

  String _getGroupCommandText(GroupCommand content, ID sender) {
    // ...
    return 'unsupported group command: ${content.cmd}';
  }

}

/// Default Builder
class DefaultMessageBuilder extends MessageBuilder {
  factory DefaultMessageBuilder() => _instance;
  static final DefaultMessageBuilder _instance = DefaultMessageBuilder._internal();
  DefaultMessageBuilder._internal();

  @override
  String getName(ID identifier) => ContactInfo.fromID(identifier).name;

}
