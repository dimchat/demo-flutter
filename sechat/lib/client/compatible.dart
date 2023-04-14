import 'package:dim_client/dim_client.dart';

abstract class Compatible {

  static void fixMetaAttachment(ReliableMessage rMsg) {
    Map? meta = rMsg['meta'];
    if (meta != null) {

    }
  }

  static void fixMetaVersion(Map meta) {
    int? version = meta['version'];
    if (version == null) {
      meta['version'] = meta['type'];
    } else if (!meta.containsKey('type')) {
      meta['type'] = version;
    }
  }

  static Command fixCommand(Command content) {
    // 1. fix 'cmd'
    content = fixCmd(content);
    // 2. fix other commands
    if (content is MetaCommand) {
      Map? meta = content['meta'];
      if (meta != null) {
        fixMetaVersion(meta);
      }
    } else if (content is ReceiptCommand) {
      fixReceiptCommand(content);
    }
    // OK
    return content;
  }

  static Command fixCmd(Command content) {
    String? cmd = content['cmd'];
    if (cmd == null) {
      cmd = content['command'];
      content['cmd'] = cmd;
    } else if (!content.containsKey('command')) {
      content['command'] = cmd;
      content = Command.parse(content.dictionary)!;
    }
    return content;
  }

  static void fixReceiptCommand(ReceiptCommand content) {
    // TODO: check for v2.0
  }

}
