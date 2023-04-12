import 'package:flutter/services.dart';

class ChannelNames {

  static const messenger = 'chat.dim/messenger';

  static const conversation = 'chat.dim/conversation';
}

class ChannelMethods {

  //
  //  Messenger channel
  //

  //
  //  Conversation channel
  //
  static const conversationsOfUser = 'conversationsOfUser';
  static const messagesOfConversation = 'messagesOfConversation';
}

class ChannelManager {

  static final ChannelManager _instance = ChannelManager();

  static ChannelManager get instance => _instance;

  //
  //  Channels
  //
  final ConversationChannel conversationChannel = ConversationChannel(ChannelNames.conversation);
}

class ConversationChannel extends MethodChannel {
  ConversationChannel(super.name);

  Future<List?> getConversations() async {
    try {
      return await invokeMethod(ChannelMethods.conversationsOfUser);
    } on PlatformException {
      return null;
    }
  }

  Future<List?> getMessages(String cid) async {
    try {
      return await invokeMethod(ChannelMethods.messagesOfConversation, {
        'identifier': cid,
      });
    } on PlatformException {
      return null;
    }
  }
}
