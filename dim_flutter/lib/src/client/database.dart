
import 'package:dim_client/ok.dart';
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

class SharedDatabase with Logging
    implements AccountDBI, SessionDBI, MessageDBI,
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
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user, {
    int sign = 1,
    required int decrypt,
  }) async {
    user = user.withoutTerminal();  // Naked ID
    return await privateKeyTable.savePrivateKey(key, type, user, sign: sign, decrypt: decrypt);
  }

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    user = user.withoutTerminal();  // Naked ID
    return await privateKeyTable.getPrivateKeysForDecryption(user);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async {
    user = user.withoutTerminal();  // Naked ID
    return await privateKeyTable.getPrivateKeyForSignature(user);
  }

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    user = user.withoutTerminal();  // Naked ID
    return await privateKeyTable.getPrivateKeyForVisaSignature(user);
  }

  //
  //  Meta Table
  //

  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    entity = entity.withoutTerminal();  // Naked ID
    // check meta with ID
    bool ok = meta.isValid && meta.matchIdentifier(entity);
    if (!ok) {
      logError('meta not match: $entity => $meta');
      assert(false, 'meta not match: $entity => $meta');
      return false;
    }
    return await metaTable.saveMeta(meta, entity);
  }

  @override
  Future<Meta?> getMeta(ID entity) async {
    entity = entity.withoutTerminal();  // Naked ID
    return await metaTable.getMeta(entity);
  }

  //
  //  Document Table
  //

  @override
  Future<bool> saveDocument(Document doc, ID entity) async {
    String? terminal = entity.terminal;
    if (terminal != null) {
      entity = entity.withoutTerminal();  // Named ID
      // check terminal in visa document
      if (doc is Visa) {
        // String? old = DocumentUtils.getVisaTerminal(doc);
        String? old = doc.getString('terminal');
        if (old == null || old == '' || old == '*') {
          doc['terminal'] = terminal;
        }
      }
    // } else if (doc is Bulletin) {
    //   // check found of group in bulletin document
    //   ID? founder = doc.founder;
    //   if (founder != null) {
    //     final gMeta = await getMeta($entity);
    //     final fMeta = await getMeta(founder);
    //     if (fMeta?.publicKey != gMeta!.publicKey) {
    //       assert(false, 'founder error: $founder, group: $entity');
    //       return false;
    //     }
    //   }
    }
    // check ID
    ID? did = DocumentUtils.getDocumentID(doc);
    if (did == null) {
      logWarning('set id for document: $entity, $doc');
      doc['did'] = entity.toString();
    } else if (!did.isSameAs(entity)) {
      logError('document id not match: $entity, $doc');
      return false;
    }
    // check document with meta.key
    Meta? meta = await getMeta(entity);
    if (meta == null) {
      assert(false, 'meta not exists: $entity');
      return false;
    } else if (!doc.verify(meta.publicKey)) {
      assert(false, 'document invalid: $entity, $doc');
      return false;
    }
    // OK, save to local storage
    return await documentTable.saveDocument(doc, entity);
  }

  @override
  Future<List<Document>> getDocuments(ID entity) async {
    String? terminal = entity.terminal;
    if (terminal != null) {
      entity = entity.withoutTerminal();  // Naked ID
    }
    // load
    List<Document> documents = await documentTable.getDocuments(entity);
    int total = documents.length;
    if (terminal != null) {
      // filter for terminal
      List<Document> array = [];
      int index = 0;
      for (final doc in documents) {
        index += 1;
        if (doc is Visa && doc.terminal != terminal) {
          // visa terminal not matched
          logInfo('[$index/$total] skip visa not for: $entity/$terminal, ${doc.terminal}');
        } else {
          logInfo('[$index/$total]  got document for: $entity/$terminal, ${doc['terminal']}');
          array.add(doc);
        }
      }
      logInfo('filter ${array.length}/$total document(s) for user: $entity/$terminal');
      documents = array;
    } else {
      logInfo('loaded $total document(s) for user: $entity');
    }
    return documents;
  }

  //
  //  User Table
  //

  @override
  Future<List<ID>> getLocalUsers() async => await userTable.getLocalUsers();

  @override
  Future<bool> saveLocalUsers(List<ID> users) async => await userTable.saveLocalUsers(users);

  Future<bool> addUser(ID user) async {
    user = user.withoutTerminal(); // Naked ID
    return await userTable.addUser(user);
  }

  Future<bool> removeUser(ID user) async {
    user = user.withoutTerminal(); // Naked ID
    return await userTable.removeUser(user);
  }

  Future<bool> setCurrentUser(ID user) async {
    user = user.withoutTerminal(); // Naked ID
    return await userTable.setCurrentUser(user);
  }

  Future<ID?> getCurrentUser() async => await userTable.getCurrentUser();

  //
  //  Contact Table
  //

  @override
  Future<List<ID>> getContacts({required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await contactTable.getContacts(user: user);
  }

  @override
  Future<bool> saveContacts(List<ID> contacts, {required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await contactTable.saveContacts(contacts, user: user);
  }

  Future<bool> addContact(ID contact, {required ID user}) async {
    contact = contact.withoutTerminal(); // Naked ID
    user = user.withoutTerminal(); // Naked ID
    return await contactTable.addContact(contact, user: user);
  }

  Future<bool> removeContact(ID contact, {required ID user}) async {
    contact = contact.withoutTerminal(); // Naked ID
    user = user.withoutTerminal(); // Naked ID
    return await contactTable.removeContact(contact, user: user);
  }

  //
  //  Remark Table
  //

  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await remarkTable.getRemark(contact, user: user);
  }

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await remarkTable.setRemark(remark, user: user);
  }

  //
  //  Blocked Table
  //

  @override
  Future<List<ID>> getBlockList({required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await blockedTable.getBlockList(user: user);
  }

  @override
  Future<bool> saveBlockList(List<ID> contacts, {required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await blockedTable.saveBlockList(contacts, user: user);
  }

  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    contact = contact.withoutTerminal(); // Naked ID
    user = user.withoutTerminal(); // Naked ID
    return await blockedTable.addBlocked(contact, user: user);
  }

  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async {
    contact = contact.withoutTerminal(); // Naked ID
    user = user.withoutTerminal(); // Naked ID
    return await blockedTable.removeBlocked(contact, user: user);
  }

  //
  //  Muted Table
  //

  @override
  Future<List<ID>> getMuteList({required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await mutedTable.getMuteList(user: user);
  }

  @override
  Future<bool> saveMuteList(List<ID> contacts, {required ID user}) async {
    user = user.withoutTerminal(); // Naked ID
    return await mutedTable.saveMuteList(contacts, user: user);
  }

  @override
  Future<bool> addMuted(ID contact, {required ID user}) async {
    contact = contact.withoutTerminal(); // Naked ID
    user = user.withoutTerminal(); // Naked ID
    return await mutedTable.addMuted(contact, user: user);
  }

  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    contact = contact.withoutTerminal(); // Naked ID
    user = user.withoutTerminal(); // Naked ID
    return await mutedTable.removeMuted(contact, user: user);
  }

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

  Future<bool> addMember(ID member, {required ID group}) async {
    member = member.withoutTerminal(); // Naked ID
    return await groupTable.addMember(member, group: group);
  }

  Future<bool> removeMember(ID member, {required ID group}) async {
    member = member.withoutTerminal(); // Naked ID
    return await groupTable.removeMember(member, group: group);
  }

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
Future<List<Pair<LoginCommand, ReliableMessage>>> getLoginCommandMessages(ID user) async {
    String? terminal = user.terminal;
    if (terminal != null) {
      user = user.withoutTerminal(); // Naked ID
    }
    // load
    var records = await loginTable.getLoginCommandMessages(user);
    int total = records.length;
    if (terminal != null) {
      // filter for terminal
      List<Pair<LoginCommand, ReliableMessage>> array = [];
      LoginCommand cmd;
      int index = 0;
      for (final pair in records) {
        cmd = pair.first;
        index += 1;
        if (cmd.terminal != terminal) {
          // login terminal not matched
          logInfo('[$index/$total]   skip login not for: $user/$terminal, $cmd');
        } else {
          logInfo('[$index/$total] got login record for: $user/$terminal, $cmd');
          array.add(pair);
        }
      }
      records = array;
    } else {
      logInfo('loaded $total login command(s) for user: $user');
    }
    return records;
  }

  @override
  Future<bool> saveLoginCommandMessage(ID user, LoginCommand content, ReliableMessage rMsg) async {
    String? terminal = user.terminal;
    if (terminal != null) {
      user = user.withoutTerminal();  // Naked ID
      // String? old = content.terminal;
      String? old = content.getString('terminal');
      if (old == null || old == '' || old == '*') {
        content['terminal'] = terminal;
      }
    }
    // save
    return await loginTable.saveLoginCommandMessage(user, content, rMsg);
  }

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
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat, {
    required ID user,
    int start = 0, int? limit,
  }) async => await instantMessageTable.getInstantMessages(chat,
    user: user,
    start: start, limit: limit,
  );

  @override
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg, {
    required ID user,
  }) async => await instantMessageTable.saveInstantMessage(chat, iMsg,
    user: user,
  );

  @override
  Future<bool> removeInstantMessage(ID chat, Envelope envelope, Content content, {
    required ID user,
  }) async => await instantMessageTable.removeInstantMessage(chat, envelope, content,
    user: user,
  );

  @override
  Future<bool> removeInstantMessages(ID chat, {
    required ID user,
  }) async => await instantMessageTable.removeInstantMessages(chat,
    user: user,
  );

  Future<int> burnMessages(DateTime expired, {
    required ID user,
  }) async => await instantMessageTable.burnMessages(expired,
    user: user,
  );

  //
  //  Conversation Table
  //

  @override
  Future<List<Conversation>> getConversations({
    required ID user,
  }) async => await conversationTable.getConversations(
    user: user,
  );

  @override
  Future<bool> addConversation(Conversation chat, {
    required ID user,
  }) async => await conversationTable.addConversation(chat,
    user: user,
  );

  @override
  Future<bool> updateConversation(Conversation chat, {
    required ID user,
  }) async => await conversationTable.updateConversation(chat,
    user: user,
  );

  @override
  Future<bool> removeConversation(ID chat, {
    required ID user,
  }) async => await conversationTable.removeConversation(chat,
    user: user,
  );

  Future<int> burnConversations(DateTime expired, {
    required ID user,
  }) async =>
      await conversationTable.burnConversations(expired, user: user);

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
  Future<Mapper?> getAppCustomizedInfo(String key, {String? mod}) async =>
      await appInfoTable.getAppCustomizedInfo(key, mod: mod);

  @override
  Future<bool> saveAppCustomizedInfo(Mapper content, String key, {Duration? expires}) async =>
      await appInfoTable.saveAppCustomizedInfo(content, key, expires: expires);

  @override
  Future<bool> clearExpiredAppCustomizedInfo() async =>
      await appInfoTable.clearExpiredAppCustomizedInfo();

}
