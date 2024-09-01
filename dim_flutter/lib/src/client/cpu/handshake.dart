import 'package:dim_client/dim_client.dart';


class ClientHandshakeProcessor extends HandshakeCommandProcessor {
  ClientHandshakeProcessor(super.facebook, super.messenger);

  static const String kTestSpeed = 'Nice to meet you!';
  static const String kTestSpeedRespond = 'Nice to meet you too!';

  static HandshakeCommand createTestSpeedCommand() =>
      BaseHandshakeCommand.from(kTestSpeed);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is HandshakeCommand, 'handshake command error: $content');
    HandshakeCommand command = content as HandshakeCommand;
    String title = command.title;
    if (title == kTestSpeedRespond) {
      logWarning('ignore test speed respond: $content');
      return [];
    } else if (title == kTestSpeed) {
      logError('unexpected test speed command: $content');
      return [];
    }
    return await super.process(content, rMsg);
  }

}
