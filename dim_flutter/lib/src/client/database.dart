
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/dbi/app.dart';
import '../common/dbi/contact.dart';
import '../common/dbi/message.dart';
import '../common/dbi/network.dart';

import '../models/chat.dart';

import '../sqlite/app.dart';

import '../sqlite/contact.dart';
import '../sqlite/conversation.dart';
import '../sqlite/document.dart';
import '../sqlite/group.dart';
import '../sqlite/group_history.dart';
import '../sqlite/keys.dart';
import '../sqlite/login.dart';
import '../sqlite/message.dart';
import '../sqlite/meta.dart';
import '../sqlite/service.dart';
import '../sqlite/speed.dart';
import '../sqlite/station.dart';
import '../sqlite/trace.dart';
import '../sqlite/user.dart';

import '../sqlite/alias.dart';
import '../sqlite/blocked.dart';
import '../sqlite/muted.dart';

class SharedDatabase implements AccountDBI, SessionDBI, MessageDBI,
                                AppCustomizedInfoDBI,
                                ConversationDBI, InstantMessageDBI, TraceDBI,
                                RemarkDBI, BlockedDBI, MutedDBI,
                                SpeedDBI {

  /// Account
  final PrivateKeyDBI privateKeyTable = PrivateKeyCache();
  final MetaDBI metaTable = MetaCache();
  final DocumentDBI documentTable = DocumentCache();

  final UserCache userTable = UserCache();
  final ContactCache contactTable = ContactCache();

  final GroupCache groupTable = GroupCache();
  final GroupHistoryDBI groupHistoryTable = GroupHistoryCache();

  final RemarkDBI remarkTable = RemarkCache();
  final BlockedDBI blockedTable = BlockedCache();
  final MutedDBI mutedTable = MutedCache();

  /// Session
  final LoginDBI loginTable = LoginCommandCache();
  final ProviderDBI providerTable = ProviderCache();
  final StationDBI stationTable = StationCache();
  final SpeedDBI speedTable = SpeedTable();

  /// Message
  final CipherKeyDBI msgKeyTable = MsgKeyCache();
  final InstantMessageTable instantMessageTable = InstantMessageTable();
  final TraceDBI traceTable = TraceTable();
  final ConversationCache conversationTable = ConversationCache();

  final NotificationCenter _center = NotificationCenter();
  NotificationCenter get center => _center;

  final AppCustomizedInfoDBI appInfoTable = CustomizedInfoCache();

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
  Future<List<Document>> getDocuments(ID entity) async =>
      await documentTable.getDocuments(entity);

  //
  //  User Table
  //

  @override
  Future<List<ID>> getLocalUsers() async => await userTable.getLocalUsers();

  @override
  Future<bool> saveLocalUsers(List<ID> users) async => await userTable.saveLocalUsers(users);

  Future<bool> addUser(ID user) async => await userTable.addUser(user);

  Future<bool> removeUser(ID user) async => await userTable.removeUser(user);

  Future<bool> setCurrentUser(ID user) async => await userTable.setCurrentUser(user);

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

  Future<bool> addContact(ID contact, {required ID user}) async =>
      await contactTable.addContact(contact, user: user);

  Future<bool> removeContact(ID contact, {required ID user}) async =>
      await contactTable.removeContact(contact, user: user);

  //
  //  Remark Table
  //

  @override
  Future<List<ContactRemark>> allRemarks({required ID user}) async =>
      await remarkTable.allRemarks(user: user);

  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async =>
      await remarkTable.getRemark(contact, user: user);

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async =>
      await remarkTable.setRemark(remark, user: user);

  //
  //  Blocked Table
  //

  @override
  Future<List<ID>> getBlockList({required ID user}) async =>
      await blockedTable.getBlockList(user: user);

  @override
  Future<bool> saveBlockList(List<ID> contacts, {required ID user}) async =>
      await blockedTable.saveBlockList(contacts, user: user);

  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async =>
      await blockedTable.addBlocked(contact, user: user);

  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async =>
      await blockedTable.removeBlocked(contact, user: user);

  //
  //  Muted Table
  //

  @override
  Future<List<ID>> getMuteList({required ID user}) async =>
      await mutedTable.getMuteList(user: user);

  @override
  Future<bool> saveMuteList(List<ID> contacts, {required ID user}) async =>
      await mutedTable.saveMuteList(contacts, user: user);

  @override
  Future<bool> addMuted(ID contact, {required ID user}) async =>
      await mutedTable.addMuted(contact, user: user);

  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async =>
      await mutedTable.removeMuted(contact, user: user);

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

  Future<bool> addMember(ID member, {required ID group}) async =>
      await groupTable.addMember(member, group: group);

  Future<bool> removeMember(ID member, {required ID group}) async =>
      await groupTable.removeMember(member, group: group);

  @override
  Future<List<ID>> getAssistants({required ID group}) async =>
      await groupTable.getAssistants(group: group);

  @override
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async =>
      await groupTable.saveAssistants(bots, group: group);

  @override
  Future<List<ID>> getAdministrators({required ID group}) async =>
      await groupTable.getAdministrators(group: group);

  @override
  Future<bool> saveAdministrators(List<ID> members, {required ID group}) async =>
      await groupTable.saveAdministrators(members, group: group);

  Future<bool> removeGroup({required ID group}) async =>
      await groupTable.removeGroup(group: group);

  //
  //  Group History Table
  //

  @override
  Future<bool> saveGroupHistory(GroupCommand content, ReliableMessage rMsg, {required ID group}) async =>
      await groupHistoryTable.saveGroupHistory(content, rMsg, group: group);

  @override
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({required ID group}) async =>
      await groupHistoryTable.getGroupHistories(group: group);

  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group}) async =>
      await groupHistoryTable.getResetCommandMessage(group: group);

  @override
  Future<bool> clearGroupAdminHistories({required ID group}) async =>
      await groupHistoryTable.clearGroupAdminHistories(group: group);

  @override
  Future<bool> clearGroupMemberHistories({required ID group}) async =>
      await groupHistoryTable.clearGroupMemberHistories(group: group);

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
  Future<List<ProviderInfo>> allProviders() async =>
      await providerTable.allProviders();

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
  Future<List<StationInfo>> allStations({required ID provider}) async =>
      await stationTable.allStations(provider: provider);

  @override
  Future<bool> addStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider}) async =>
      await stationTable.addStation(sid, chosen: chosen,
          host: host, port: port, provider: provider);

  @override
  Future<bool> updateStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider}) async =>
      await stationTable.updateStation(sid, chosen: chosen,
          host: host, port: port, provider: provider);

  @override
  Future<bool> removeStation({required String host, required int port, required ID provider}) async =>
      await stationTable.removeStation(host: host, port: port, provider: provider);

  @override
  Future<bool> removeStations({required ID provider}) async =>
      await stationTable.removeStations(provider: provider);

  //
  //  Speed Table
  //

  @override
  Future<List<SpeedRecord>> getSpeeds(String host, int port) async =>
      await speedTable.getSpeeds(host, port);

  @override
  Future<bool> addSpeed(String host, int port,
      {required ID identifier, required DateTime time, required double duration,
        required String? socketAddress}) async =>
      await speedTable.addSpeed(host, port,
          identifier: identifier, time: time, duration: duration, socketAddress: socketAddress);

  @override
  Future<bool> removeExpiredSpeed(DateTime? expired) async =>
      await speedTable.removeExpiredSpeed(expired);

  //
  //  MsgKey Table
  //

  @override
  Future<SymmetricKey?> getCipherKey({required ID sender, required ID receiver,
    bool generate = false}) async =>
      await msgKeyTable.getCipherKey(sender: sender, receiver: receiver, generate: generate);

  @override
  Future<void> cacheCipherKey({required ID sender, required ID receiver,
    required SymmetricKey key}) async =>
      await msgKeyTable.cacheCipherKey(sender: sender, receiver: receiver, key: key);

  @override
  Map getGroupKeys({required ID group, required ID sender}) {
    // TODO: implement getGroupKeys
    Log.error('implement getGroupKeys: $group');
    return {};
  }

  @override
  bool saveGroupKeys({required ID group, required ID sender, required Map keys}) {
    // TODO: implement saveGroupKeys
    Log.error('implement saveGroupKeys: $group');
    return true;
  }

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
  Future<bool> removeInstantMessage(ID chat, Envelope envelope, Content content) async =>
      await instantMessageTable.removeInstantMessage(chat, envelope, content);

  @override
  Future<bool> removeInstantMessages(ID chat) async =>
      await instantMessageTable.removeInstantMessages(chat);

  Future<int> burnMessages(DateTime expired) async =>
      await instantMessageTable.burnMessages(expired);

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

  Future<int> burnConversations(DateTime expired) async =>
      await conversationTable.burnConversations(expired);

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

  //
  //  App Customized Info
  //

  @override
  Future<Content?> getAppCustomizedContent(String key, {String? mod}) async =>
      await appInfoTable.getAppCustomizedContent(key, mod: mod);

  @override
  Future<bool> saveAppCustomizedContent(Content content, String key, {Duration? expires}) async =>
      await appInfoTable.saveAppCustomizedContent(content, key, expires: expires);

  @override
  Future<bool> clearExpiredAppCustomizedContents(String key) async =>
      await appInfoTable.clearExpiredAppCustomizedContents(key);

}
