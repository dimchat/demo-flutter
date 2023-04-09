import 'package:flutter/services.dart';

class ChannelNames {

  static const register = 'chat.dim/register';

  static const facebook = 'chat.dim/facebook';

  static const messenger = 'chat.dim/messenger';

  static const conversation = 'chat.dim/conversation';
}

class ChannelMethods {

  //
  //  Register channel
  //
  static const createUser = 'createUser';

  //
  //  Facebook channel
  //
  static const currentUser = 'currentUser';
  static const contactsOfUser = 'contactsOfUser';

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
  final RegisterChannel registerChannel = RegisterChannel(ChannelNames.register);
  final FacebookChannel facebookChannel = FacebookChannel(ChannelNames.facebook);
  final ConversationChannel conversationChannel = ConversationChannel(ChannelNames.conversation);
}

class RegisterChannel extends MethodChannel {
  RegisterChannel(super.name);

  Future<String> createUser(String name, String avatar) async {
    try {
      return await invokeMethod(ChannelMethods.createUser, {
        "name": name, "avatar": avatar
      });
    } on PlatformException catch (e) {
      return e.toString();
    }
  }
}

class FacebookChannel extends MethodChannel {
  FacebookChannel(super.name);

  static bool isID(String? string) {
    if (string != null && string.startsWith("0x")) {
      return string.length == 42;
    }
    // TODO: other format
    return false;
  }

  Future<Map> getCurrentUser() async {
    try {
      return await invokeMethod(ChannelMethods.currentUser);
    } on PlatformException catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<List?> getContacts() async {
    try {
      return await invokeMethod(ChannelMethods.contactsOfUser);
    } on PlatformException {
      return null;
    }
  }
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
