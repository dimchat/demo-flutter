import 'package:get/get.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import 'chat.dart';

abstract class MessageBuilder with Logging {

  // protected
  String getName(ID identifier);

  // protected
  String getNames(Iterable<ID> members) {
    List<String> names = [];
    for (var item in members) {
      names.add(getName(item));
    }
    return names.join(', ');
  }

  /// Check whether this message content should be ignored
  bool isHiddenContent(Content content, ID sender) {
    if (content is ResetCommand) {
      return false;
    } else if (content is InviteCommand) {
      return false;
    } else if (content is ExpelCommand) {
      return false;
    } else if (content is JoinCommand) {
      return false;
    } else if (content is QuitCommand) {
      return false;
    } else {
      return isCommand(content, sender);
    }
  }
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
      Map? replacements = content['replacements'];
      if (template != null && replacements != null) {
        return _getTempText(template, replacements);
      }
      if (content is Command) {
        return _getCommandText(content, sender);
      }
      return _getContentText(content);
    } catch (e, st) {
      logError('content error: $e, $content, $st');
      return e.toString();
    }
  }

  String _getTempText(String template, Map replacements) {
    logInfo('template: $template');
    String text = template;
    replacements.forEach((key, value) {
      if (key == 'ID' || key == 'sender' || key == 'receiver' || key == 'group') {
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
      text = '[URL:${content.title}]';
    } else if (content is NameCard) {
      text = '[NameCard:${content.name}]';
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
    if (content is ResetCommand) {
      return _getResetCommandText(content, sender);
    } else if (content is InviteCommand) {
      return _getInviteCommandText(content, sender);
    } else if (content is ExpelCommand) {
      return _getExpelCommandText(content, sender);
    } else if (content is JoinCommand) {
      return _getJoinCommandText(content, sender);
    } else if (content is QuitCommand) {
      return _getQuitCommandText(content, sender);
    }
    // ...
    return 'unsupported group command: @cmd'.trParams({
      'cmd': content.cmd,
    });
  }

  String _getResetCommandText(ResetCommand content, ID sender) {
    String commander = getName(sender);
    return '"@commander" has updated the group members.'.trParams({
      'commander': commander,
    });
  }

  String _getJoinCommandText(JoinCommand content, ID sender) {
    String commander = getName(sender);
    return '"@commander" wants to join this group.'.trParams({
      'commander': commander,
    });
  }

  String _getQuitCommandText(QuitCommand content, ID sender) {
    String commander = getName(sender);
    return '"@commander" left the group.'.trParams({
      'commander': commander,
    });
  }

  String _getInviteCommandText(InviteCommand content, ID sender) {
    String commander = getName(sender);
    var someone = content.member;
    var members = content.members;
    if (members == null || members.isEmpty) {
      assert(someone != null, 'failed to get group member: $content');
      members = null;
    } else if (members.length == 1) {
      someone = members[0];
      members = null;
    } else {
      assert(someone == null, 'group member error: $content');
      someone = null;
    }
    if (members != null) {
      return '"@commander" is inviting "@members" into this group.'.trParams({
      'commander': commander,
      'members': getNames(members),
      });
    } else if (someone != null) {
      return '"@commander" is inviting "@member" into this group.'.trParams({
      'commander': commander,
      'member': getName(someone),
      });
    } else {
      assert(false, 'should not happen: $content');
      return 'Invite command error.'.tr;
    }
  }

  String _getExpelCommandText(ExpelCommand content, ID sender) {
    String commander = getName(sender);
    var someone = content.member;
    var members = content.members;
    if (members == null || members.isEmpty) {
      assert(someone != null, 'failed to get group member: $content');
      members = null;
    } else if (members.length == 1) {
      someone = members[0];
      members = null;
    } else {
      assert(someone == null, 'group member error: $content');
      someone = null;
    }
    if (members != null) {
      return '"@commander" is expelling members "@members" from this group.'.trParams({
        'commander': commander,
        'members': getNames(members),
      });
    } else if (someone != null) {
      return '"@commander" is expelling member "@member" from this group.'.trParams({
        'commander': commander,
        'member': getName(someone),
      });
    } else {
      assert(false, 'should not happen: $content');
      return 'Expel command error.'.tr;
    }
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
      logWarning('failed to get conversation: $identifier');
      return Anonymous.getName(identifier);
    }
    return chat.name;
  }

}
