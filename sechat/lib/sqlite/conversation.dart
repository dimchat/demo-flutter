import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';

import '../client/shared.dart';

class Conversation {
  Conversation(this.identifier, this.name, this.image, this.unread, this.lastMessage, this.lastTime);

  final ID identifier;
  final String name;
  final String? image;  // URL

  int unread;           // count of unread messages

  String? lastMessage;  // description of last message
  DateTime? lastTime;   // time of last message

  Widget getIcon(double? size) {
    if (image != null) {
      // TODO: build icon
      return Icon(CupertinoIcons.photo, size: size);
    } else if (identifier.isUser) {
      return Icon(CupertinoIcons.profile_circled, size: size);
    } else {
      return Icon(CupertinoIcons.person_2_fill, size: size);
    }
  }

  static Future<Conversation> create(ID chat) async {
    GlobalVariable shared = GlobalVariable();
    String name = await shared.facebook.getName(chat);
    Document? doc = await shared.facebook.getDocument(chat, '*');
    String? avatar = doc is Visa ? doc.avatar : null;
    // TODO:
    int unread = 0;
    String? lastMessage;
    DateTime? lastTime;
    return Conversation(chat, name, avatar, unread, lastMessage, lastTime);
  }

  static Future<List<Conversation>> createList(List<ID> conversations) async {
    List<Conversation> array = [];
    for (ID item in conversations) {
      array.add(await create(item));
    }
    return array;
  }

}

abstract class ConversationDBI {

  ///  Get all conversations
  ///
  /// @return chat box ID list
  Future<List<ID>> getConversations();

  ///  Add conversation
  ///
  /// @param chat - conversation ID
  /// @return true on success
  Future<bool> addConversation(ID chat);

  ///  Remove conversation
  ///
  /// @param chat - conversation ID
  /// @return true on success
  Future<bool> removeConversation(ID chat);

}

abstract class InstantMessageDBI {

  ///  Get stored messages
  ///
  /// @param chat  - conversation ID
  /// @param start - start position for loading message
  /// @param limit - max count for loading message
  /// @return partial messages and remaining count, 0 means there are all messages cached
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat,
      {int start = 0, int? limit});

  ///  Save the message
  ///
  /// @param chat - conversation ID
  /// @param iMsg - instant message
  /// @return true on success
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg);

  ///  Delete the message
  ///
  /// @param chat - conversation ID
  /// @param iMsg - instant message
  /// @return true on row(s) affected
  Future<bool> removeInstantMessage(ID chat, InstantMessage iMsg);

}

abstract class TraceDBI {

  ///  Update message state with receipt
  ///
  /// @param iMsg - message with receipt content
  /// @param chat - conversation ID
  /// @return true while target message found
  Future<bool> saveReceipt(InstantMessage iMsg, ID chat);

}
