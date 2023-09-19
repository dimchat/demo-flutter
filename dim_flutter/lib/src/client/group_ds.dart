/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */
import 'package:dim_client/dim_client.dart';

class GroupDelegate implements GroupDataSource {
  GroupDelegate(this.facebook, this.messenger);

  // private
  final CommonFacebook facebook;
  // private
  final CommonMessenger messenger;

  // private
  Future<User?> get currentUser async => await facebook.currentUser;

  //
  //  EntityDataSource
  //

  @override
  Future<Meta?> getMeta(ID identifier) async {
    Meta? meta = await facebook.getMeta(identifier);
    if (meta == null) {
      messenger.queryMeta(identifier);
    }
    return meta;
  }

  @override
  Future<Document?> getDocument(ID identifier, String? docType) async {
    Document? doc = await facebook.getDocument(identifier, docType);
    if (doc == null) {
      messenger.queryDocument(identifier);
    }
    return doc;
  }

  //
  //  GroupDataSource
  //

  @override
  Future<ID?> getFounder(ID group) async {
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      return null;
    }
    return await facebook.getFounder(group);
  }

  @override
  Future<ID?> getOwner(ID group) async {
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      return null;
    }
    return await facebook.getOwner(group);
  }

  //
  //  Membership
  //

  Future<bool> isFounder(ID user, {required ID group}) async {
    ID? founder = await getFounder(group);
    if (founder != null) {
      return founder == user;
    }
    // check member's public key with group's meta.key
    Meta? gMeta = await getMeta(group);
    assert(gMeta != null, 'failed to get meta for group: $group');
    Meta? mMeta = await getMeta(user);
    assert(mMeta != null, 'failed to get meta for member: $user');
    return gMeta?.matchPublicKey(mMeta!.publicKey) ?? false;
  }

  Future<bool> isOwner(ID user, {required ID group}) async {
    ID? owner = await getOwner(group);
    if (owner != null) {
      return owner == user;
    }
    if (group.type == EntityType.kGroup ) {
      // this is a polylogue
      return await isFounder(user, group: group);
    }
    throw Exception('only Polylogue so far');
  }

  Future<bool> isMember(ID user, {required ID group}) async {
    List<ID> members = await getMembers(group);
    return members.contains(user);
  }

  Future<bool> isAdministrator(ID user, {required ID group}) async {
    AccountDBI db = facebook.database;
    List<ID> admins = await db.getAdministrators(group: group);
    return admins.contains(user);
  }

  Future<bool> isAssistant(ID user, {required ID group}) async {
    List<ID> bots = await facebook.getAssistants(group);
    return bots.contains(user);
  }

  //
  //  Group Bots
  //

  @override
  Future<List<ID>> getAssistants(ID group) async {
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      return [];
    }
    return await facebook.getAssistants(group);
  }

  // private
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async {
    AccountDBI db = facebook.database;
    return await db.saveAssistants(bots, group: group);
  }

  //
  //  Administrators
  //

  Future<List<ID>> getAdministrators(ID group) async {
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      return [];
    }
    AccountDBI db = facebook.database;
    List<ID> members = await db.getAdministrators(group: group);
    return [...members];  // clone
  }

  Future<bool> saveAdministrators(List<ID> members, {required ID group}) async {
    AccountDBI db = facebook.database;
    return await db.saveAdministrators(members, group: group);
  }

  //
  //  Members
  //

  @override
  Future<List<ID>> getMembers(ID group) async {
    Document? doc = await getDocument(group, '*');
    if (doc == null) {
      return [];
    }
    List<ID> members = await facebook.getMembers(group);
    return [...members];  // clone
  }

  Future<bool> saveMembers(List<ID> members, {required ID group}) async {
    AccountDBI db = facebook.database;
    return await db.saveMembers(members, group: group);
  }

  Future<bool> addMember(ID member, {required ID group}) async {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = await getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos >= 0) {
      // already exists
      return false;
    }
    allMembers.add(member);
    return await saveMembers(allMembers, group: group);
  }

  Future<bool> removeMember(ID member, {required ID group}) async {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = await getMembers(group);
    int pos = allMembers.indexOf(member);
    if (pos < 0) {
      // not exists
      return false;
    }
    allMembers.removeAt(pos);
    return await saveMembers(allMembers, group: group);
  }

  Future<List<ID>> addMembers(List<ID> newMembers, {required ID group}) async {
    List<ID> members = await getMembers(group);
    int count = 0;
    for (ID member in newMembers) {
      if (members.contains(member)) {
        continue;
      }
      members.add(member);
      ++count;
    }
    if (count > 0) {
      await saveMembers(members, group: group);
    }
    return members;
  }

  Future<List<ID>> removeMembers(List<ID> outMembers, {required ID group}) async {
    List<ID> members = await getMembers(group);
    int count = 0;
    for (ID member in outMembers) {
      if (!members.contains(member)) {
        continue;
      }
      members.remove(member);
      ++count;
    }
    if (count > 0) {
      await saveMembers(members, group: group);
    }
    return members;
  }

}
