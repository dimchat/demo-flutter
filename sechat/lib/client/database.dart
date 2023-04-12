import 'package:dim_client/dim_client.dart';

import '../sqlite/entity.dart';
import '../sqlite/group.dart';
import '../sqlite/keys.dart';
import '../sqlite/message.dart';
import '../sqlite/session.dart';
import '../sqlite/user.dart';
import 'dbi/account.dart';
import 'dbi/message.dart';
import 'dbi/session.dart';

class SharedDatabase implements AccountDBI, MessageDBI, SessionDBI,
                                PrivateKeyTable, UserTable, ContactTable,
                                GroupTable, ProviderTable, StationTable {

  PrivateKeyTable privateKeyTable = PrivateKeyDB();
  MetaTable metaTable = MetaDB();
  DocumentTable documentTable = DocumentDB();
  UserTable userTable = UserDB();
  ContactTable contactTable = ContactDB();
  GroupTable groupTable = GroupDB();

  ReliableMessageTable reliableMessageTable = ReliableMessageDB();
  MsgKeyTable msgKeyTable = MsgKeyDB();

  LoginTable loginTable = LoginCommandDB();
  ProviderTable providerTable = ProviderDB();
  StationTable stationTable = StationDB();

  //
  //  PrivateKey Table
  //

  @override
  Future<bool> storePrivateKey(PrivateKey key, String type, ID user,
      {required int sign, required int decrypt}) async =>
      await privateKeyTable.storePrivateKey(key, type, user,
          sign: sign, decrypt: decrypt);

  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user) async {
    if (key is DecryptKey) {
      return await storePrivateKey(key, type, user, sign: 1, decrypt: 1);
    } else {
      return await storePrivateKey(key, type, user, sign: 1, decrypt: 0);
    }
  }

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
  Future<List<ID>> getContacts(ID user) async =>
      await contactTable.getContacts(user);

  @override
  Future<bool> saveContacts(List<ID> contacts, ID user) async =>
      await contactTable.saveContacts(contacts, user);

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
  Future<ID?> getFounder(ID group) async => await groupTable.getFounder(group);

  @override
  Future<ID?> getOwner(ID group) async => await groupTable.getOwner(group);

  @override
  Future<List<ID>> getMembers(ID group) async =>
      await groupTable.getMembers(group);

  @override
  Future<bool> saveMembers(List<ID> members, ID group) async =>
      await groupTable.saveMembers(members, group);

  @override
  Future<List<ID>> getAssistants(ID group) async =>
      await groupTable.getAssistants(group);

  @override
  Future<bool> saveAssistants(List<ID> bots, ID group) async =>
      await groupTable.saveAssistants(bots, group);

  @override
  Future<bool> addMember(ID member, {required ID group}) async =>
      await groupTable.addMember(member, group: group);

  @override
  Future<bool> removeMember(ID member, {required ID group}) async =>
      await groupTable.removeMember(member, group: group);

  @override
  Future<bool> removeGroup(ID group) async =>
      await groupTable.removeGroup(group);

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
  Future<List<ProviderInfo>> getProviders() async =>
      await providerTable.getProviders();

  @override
  Future<bool> addProvider(ID identifier, {String? name, String? url, int chosen = 0}) async =>
      await providerTable.addProvider(identifier, name: name, url: url, chosen: chosen);

  @override
  Future<bool> updateProvider(ID identifier, {String? name, String? url, int chosen = 0}) async =>
      await providerTable.updateProvider(identifier, name: name, url: url, chosen: chosen);

  @override
  Future<bool> removeProvider(ID identifier) async =>
      await providerTable.removeProvider(identifier);

  //
  //  Station Table
  //

  @override
  Future<Set<Triplet<String, int, ID?>>> allNeighbors() async =>
      await stationTable.allNeighbors();

  @override
  Future<ID?> getNeighbor(String host, int port) async =>
      await stationTable.getNeighbor(host, port);

  @override
  Future<bool> addNeighbor(String host, int port, [ID? station]) async =>
      await stationTable.addNeighbor(host, port, station);

  @override
  Future<bool> removeNeighbor(String host, int port) async =>
      await stationTable.removeNeighbor(host, port);

  @override
  Future<List<StationInfo>> getStations(ID? provider) async =>
      await stationTable.getStations(provider);

  @override
  Future<bool> addStation(String host, int port,
      {ID? station, String? name, int chosen = 0, ID? provider}) async =>
      await stationTable.addStation(host, port, station: station, name: name, chosen: chosen, provider: provider);

  @override
  Future<bool> updateStation(String host, int port,
      {required ID? station, required String? name, required int chosen,
        required ID? provider}) async =>
      await stationTable.updateStation(host, port,
          station: station, name: name, chosen: chosen, provider: provider);

  @override
  Future<bool> chooseStation(String host, int port, {ID? provider}) async =>
      await stationTable.chooseStation(host, port, provider: provider);

  @override
  Future<bool> removeStation(String host, int port, {ID? provider}) async =>
      await stationTable.removeStation(host, port, provider: provider);

  @override
  Future<bool> removeStations(ID provider) async =>
      await stationTable.removeStations(provider);

}
