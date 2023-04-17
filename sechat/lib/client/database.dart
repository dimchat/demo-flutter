import 'package:dim_client/dim_client.dart';

import '../models/conversation.dart';
import '../sqlite/contact.dart';
import '../sqlite/document.dart';
import '../sqlite/group.dart';
import '../sqlite/keys.dart';
import '../sqlite/login.dart';
import '../sqlite/message.dart';
import '../sqlite/meta.dart';
import '../sqlite/session.dart';
import '../sqlite/trace.dart';
import '../sqlite/user.dart';

class SharedDatabase implements AccountDBI, SessionDBI, MessageDBI,
                                ConversationDBI, InstantMessageDBI, TraceDBI {

  PrivateKeyDBI privateKeyTable = PrivateKeyCache();
  MetaDBI metaTable = MetaCache();
  DocumentDBI documentTable = DocumentCache();
  UserDBI userTable = UserTable();
  ContactDBI contactTable = ContactTable();
  GroupDBI groupTable = GroupTable();

  LoginDBI loginTable = LoginCommandCache();
  ProviderDBI providerTable = ProviderTable();
  StationDBI stationTable = StationTable();

  CipherKeyDBI msgKeyTable = MsgKeyCache();
  ReliableMessageDBI reliableMessageTable = ReliableMessageTable();
  InstantMessageDBI instantMessageTable = InstantMessageTable();
  ConversationDBI conversationTable = ConversationTable();
  TraceDBI traceTable = TraceTable();

  final NotificationCenter _center = NotificationCenter();
  NotificationCenter get center => _center;

  //
  //  PrivateKey Table
  //

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async =>
      await privateKeyTable.savePrivateKey(key, type, user,
          sign: sign, decrypt: decrypt);

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async =>
      await privateKeyTable.getPrivateKeysForDecryption(user);

  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async =>
      await privateKeyTable.getPrivateKeyForSignature(user);

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async =>
      await privateKeyTable.getPrivateKeyForVisaSignature(user);

  //
  //  Meta Table
  //

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async =>
      await metaTable.saveMeta(meta, entity);

  @override
  Future<Meta?> getMeta(ID entity) async =>
      await metaTable.getMeta(entity);

  //
  //  Document Table
  //

  @override
  Future<bool> saveDocument(Document doc) async =>
      await documentTable.saveDocument(doc);

  @override
  Future<Document?> getDocument(ID entity, String? type) async =>
      await documentTable.getDocument(entity, type);

  //
  //  User Table
  //

  @override
  Future<List<ID>> getLocalUsers() async => await userTable.getLocalUsers();

  @override
  Future<bool> saveLocalUsers(List<ID> users) async => await userTable.saveLocalUsers(users);

  @override
  Future<bool> addUser(ID user) async => await userTable.addUser(user);

  @override
  Future<bool> removeUser(ID user) async => await userTable.removeUser(user);

  @override
  Future<bool> setCurrentUser(ID user) async => await userTable.setCurrentUser(user);

  @override
  Future<ID?> getCurrentUser() async => await userTable.getCurrentUser();

  //
  //  Contact Table
  //

  @override
  Future<List<ID>> getContacts({required ID user}) async =>
      await contactTable.getContacts(user: user);

  @override
  Future<bool> saveContacts(List<ID> contacts, {required ID user}) async =>
      await contactTable.saveContacts(contacts, user: user);

  @override
  Future<bool> addContact(ID contact, {required ID user}) async =>
      await contactTable.addContact(contact, user: user);

  @override
  Future<bool> removeContact(ID contact, {required ID user}) async =>
      await contactTable.removeContact(contact, user: user);

  //
  //  Group Table
  //

  @override
  Future<ID?> getFounder({required ID group}) async =>
      await groupTable.getFounder(group: group);

  @override
  Future<ID?> getOwner({required ID group}) async =>
      await groupTable.getOwner(group: group);

  @override
  Future<List<ID>> getMembers({required ID group}) async =>
      await groupTable.getMembers(group: group);

  @override
  Future<bool> saveMembers(List<ID> members, {required ID group}) async =>
      await groupTable.saveMembers(members, group: group);

  @override
  Future<List<ID>> getAssistants({required ID group}) async =>
      await groupTable.getAssistants(group: group);

  @override
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async =>
      await groupTable.saveAssistants(bots, group: group);

  @override
  Future<bool> addMember(ID member, {required ID group}) async =>
      await groupTable.addMember(member, group: group);

  @override
  Future<bool> removeMember(ID member, {required ID group}) async =>
      await groupTable.removeMember(member, group: group);

  @override
  Future<bool> removeGroup({required ID group}) async =>
      await groupTable.removeGroup(group: group);

  //
  //  Login Table
  //

  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async =>
      await loginTable.getLoginCommandMessage(identifier);

  @override
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) async =>
      await loginTable.saveLoginCommandMessage(identifier, content, rMsg);

  //
  //  Provider Table
  //

  @override
  Future<List<Pair<ID, int>>> getProviders() async =>
      await providerTable.getProviders();

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async =>
      await providerTable.addProvider(identifier, chosen: chosen);

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async =>
      await providerTable.updateProvider(identifier, chosen: chosen);

  @override
  Future<bool> removeProvider(ID identifier) async =>
      await providerTable.removeProvider(identifier);

  //
  //  Station Table
  //

  @override
  Future<List<Triplet<Pair<String, int>, ID, int>>> getStations({required ID provider}) async =>
      await stationTable.getStations(provider: provider);

  @override
  Future<bool> addStation(String host, int port, {required ID provider, int chosen = 0}) async =>
      await stationTable.addStation(host, port, provider: provider, chosen: chosen);

  @override
  Future<bool> updateStation(String host, int port, {required ID provider, int chosen = 0}) async =>
      await stationTable.updateStation(host, port, provider: provider, chosen: chosen);

  @override
  Future<bool> removeStation(String host, int port, {required ID provider}) async =>
      await stationTable.removeStation(host, port, provider: provider);

  @override
  Future<bool> removeStations({required ID provider}) async =>
      await stationTable.removeStations(provider: provider);

  //
  //  MsgKey Table
  //

  @override
  Future<SymmetricKey?> getCipherKey(ID sender, ID receiver,
      {bool generate = false}) async =>
      await msgKeyTable.getCipherKey(sender, receiver, generate: generate);

  @override
  Future<void> cacheCipherKey(ID sender, ID receiver, SymmetricKey? key) async =>
      await msgKeyTable.cacheCipherKey(sender, receiver, key);

  //
  //  ReliableMessage Table
  //

  @override
  Future<Pair<List<ReliableMessage>, int>> getReliableMessages(ID receiver,
      {int start = 0, int? limit}) async =>
      await reliableMessageTable.getReliableMessages(receiver,
          start: start, limit: limit);

  @override
  Future<bool> cacheReliableMessage(ID receiver, ReliableMessage rMsg) async =>
      reliableMessageTable.cacheReliableMessage(receiver, rMsg);

  @override
  Future<bool> removeReliableMessage(ID receiver, ReliableMessage rMsg) async =>
      await reliableMessageTable.removeReliableMessage(receiver, rMsg);

  //
  //  InstantMessage Table
  //

  @override
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat,
      {int start = 0, int? limit}) async =>
      await instantMessageTable.getInstantMessages(chat, start: start, limit: limit);

  @override
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg) async =>
      await instantMessageTable.saveInstantMessage(chat, iMsg);

  @override
  Future<bool> removeInstantMessage(ID chat, InstantMessage iMsg) async =>
      await instantMessageTable.removeInstantMessage(chat, iMsg);

  //
  //  Conversation Table
  //

  @override
  Future<List<Conversation>> getConversations() async =>
      await conversationTable.getConversations();

  @override
  Future<bool> addConversation(Conversation chat) async =>
      await conversationTable.addConversation(chat);

  @override
  Future<bool> updateConversation(Conversation chat) async =>
      await conversationTable.updateConversation(chat);

  @override
  Future<bool> removeConversation(ID chat) async =>
      await conversationTable.removeConversation(chat);

  //
  //  Trace Table
  //

  @override
  Future<bool> addTrace(String trace, ID cid,
      {required ID sender, required int sn, required String? signature}) async =>
      await traceTable.addTrace(trace, cid,
          sender: sender, sn: sn, signature: signature);

  @override
  Future<List<String>> getTraces(ID sender, int sn, String? signature) async =>
      await traceTable.getTraces(sender, sn, signature);

  @override
  Future<bool> removeTraces(ID sender, int sn, String? signature) async =>
      await traceTable.removeTraces(sender, sn, signature);

  @override
  Future<bool> removeAllTraces(ID cid) async =>
      await traceTable.removeAllTraces(cid);

}
