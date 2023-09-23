import 'package:dim_client/dim_client.dart';
import 'package:lnc/lnc.dart';

import 'chat.dart';

abstract class MessageBuilder {

  // protected
  String getName(ID identifier);

  /// Check whether this message content should be a command
  bool isCommand(Content content, ID sender) {
    if (content.containsKey('command')) {
      return true;
    }
    String? text = content['text'];
    if (text != null) {
      // check for text receipts
      if (_checkText(text, [
        'Document not accept',
        'Document not change',
        'Document receive',
      ])) {
        return true;
      }
    }
    // TODO: other situations?
    return content is Command;
  }
  bool _checkText(String text, List<String> array) {
    for (String prefix in array) {
      if (text.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  String getText(Content content, ID sender) {
    try {
      String? template = content['template'];
      Map? info = content['replacements'];
      if (template != null && info != null) {
        return _getTempText(template, info);
      }
      if (content is Command) {
        return _getCommandText(content, sender);
      }
      return _getContentText(content);
    } catch (e) {
      Log.error('content error: $e, $content');
      return e.toString();
    }
  }

  String _getTempText(String template, Map info) {
    Log.info('template: $template');
    String text = template;
    info.forEach((key, value) {
      if (key == 'ID') {
        ID? identifier = ID.parse(value);
        if (identifier != null) {
          value = getName(identifier);
        }
      }
      text = text.replaceAll('\${$key}', '$value');
    });
    return text;
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
    } else if (content is NameCard) {
      text = '[NameCard:${content.identifier}]';
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
  String getName(ID identifier) {
    Conversation? chat = Conversation.fromID(identifier);
    if (chat == null) {
      Log.warning('failed to get conversation: $identifier');
      return Anonymous.getName(identifier);
    }
    return chat.title;
  }

}
