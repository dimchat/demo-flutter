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

class GroupManager {
  factory GroupManager() => _instance;
  static final GroupManager _instance = GroupManager._internal();
  GroupManager._internal() {
    messenger = null;
  }

  // private
  ClientMessenger? messenger;

  // private
  Future<User?> get currentUser async => await messenger?.facebook.currentUser;

  // private
  Future<void> sendCommand(Command content, {required List<ID> members}) async {
    ID? me = (await currentUser)?.identifier;
    for (ID item in members) {
      if (item == me) {
        // skip cycled message
        continue;
      }
      await messenger?.sendContent(content, sender: me, receiver: item);
    }
  }

  ///  Reset group members
  ///
  /// @param newMembers - new member ID list
  /// @return true on success
  Future<bool> resetGroupMembers(ID group, List<ID> newMembers) async {
    assert(group.isGroup && newMembers.isNotEmpty, 'params error: $group, $newMembers');

    ID me = (await currentUser)!.identifier;

    if (await isOwner(newMembers.first, group: group)) {
      // member list OK
    } else {
      throw Exception("Group owner must be the first member: $group");
    }

    // 0. check permission
    if (me == newMembers.first || await isAdministrator(me, group: group)) {
      // only the owner or admin can reset group members
    } else {
      // not an admin/owner
      throw Exception('Cannot reset members of group: $group');
    }

    // 1. update local members
    List<ID> oldMembers = await getMembers(group: group);
    List<ID> expelList = [];
    for (ID item in oldMembers) {
      if (!newMembers.contains(item)) {
        expelList.add(item);
      }
    }
    if (await saveMembers(newMembers, group: group)) {
      // OK
    } else {
      throw Exception('Failed to update members of group: $group');
    }

    List<ID> bots = await getAssistants(group: group);
    Meta? meta = await getMeta(group);
    assert(meta != null, 'meta not found: $group');
    Document? doc = await getDocument(group, "*");
    assert(doc != null, 'document not found: $group');

    // 2. send 'meta/document' command
    Command command = doc == null
        ? MetaCommand.response(group, meta!)
        : DocumentCommand.response(group, meta, doc);
    await sendCommand(command, members: bots);              // to all assistants

    // 3. send 'reset' command
    command = GroupCommand.reset(group, members: newMembers);
    await sendCommand(command, members: bots);              // to all assistants
    await sendCommand(command, members: newMembers);        // to new members
    await sendCommand(command, members: expelList);         // to expelled members

    return true;
  }

  ///  Invite new members to this group
  ///
  /// @param newMembers - new member ID list to be added
  /// @return true on success
  Future<bool> inviteGroupMembers(ID group, List<ID> newMembers) async {
    assert(group.isGroup && newMembers.isNotEmpty, 'params error: $group, $newMembers');

    ID me = (await currentUser)!.identifier;
    List<ID> oldMembers = await getMembers(group: group);

    if (await isAdministrator(me, group: group) ||
        await isOwner(me, group: group)) {
      // You are the owner/admin, then
      // append new members and 'reset' the group
      for (ID item in newMembers) {
        if (!oldMembers.contains(item)) {
          oldMembers.add(item);
        }
      }
      return await resetGroupMembers(group, oldMembers);
    }

    // 0. check permission
    if (await isMember(me, group: group)) {
      // ordinary member
    } else {
      // not a member
      throw Exception('Cannot invite member into group: $group');
    }

    // 1. update local members
    List<ID> members = await addMembers(newMembers, group: group);

    List<ID> bots = await getAssistants(group: group);
    Meta? meta = await getMeta(group);
    assert(meta != null, 'meta not found: $group');
    Document? doc = await getDocument(group, "*");
    assert(doc != null, 'document not found: $group');

    // 2. send 'meta/document' command
    Command command = doc == null
        ? MetaCommand.response(group, meta!)
        : DocumentCommand.response(group, meta, doc);
    await sendCommand(command, members: bots);              // to all assistants
    await sendCommand(command, members: newMembers);        // to new members

    // 3. send 'invite' command
    command = GroupCommand.invite(group, members: newMembers);
    await sendCommand(command, members: bots);              // to all assistants
    await sendCommand(command, members: oldMembers);        // to old members
    command = GroupCommand.invite(group, members: members);
    await sendCommand(command, members: newMembers);        // to new members

    return true;
  }

  ///  Quit from this group
  ///
  /// @return true on success
  Future<bool> quitGroup(ID group) async {
    assert(group.isGroup, 'group ID error: $group');

    ID me = (await currentUser)!.identifier;

    // 0. check permission
    if (await isAdministrator(me, group: group)) {
      throw Exception('Administrator cannot quit from group: $group');
    } else if (await isOwner(me, group: group)) {
      throw Exception('Owner cannot quit from group: $group');
    } else if (await isMember(me, group: group)) {
      // ordinary member
    } else {
      // not a member
      assert(false, 'Not a member of group: $group');
    }

    List<ID> bots = await getAssistants(group: group);
    List<ID> members = await getMembers(group: group);

    // 1. update local storage
    bool ok = false;
    if (members.remove(me)) {
      ok = await saveMembers(members, group: group);
      //} else {
      //    // not a member now
      //    return false;
    }

    // 2. send 'quit' command
    Command command = GroupCommand.quit(group);
    await sendCommand(command, members: bots);     // to assistants
    await sendCommand(command, members: members);  // to new members

    return ok;
  }

  ///  Query group info
  ///
  /// @return false on error
  Future<bool> queryGroup(ID group) async {
    assert(group.isGroup, 'group ID error: $group');

    // ID me = (await currentUser)!.identifier;
    //
    // // 0. check permission
    // if (await isMember(me, group: group) || await isAssistant(me, group: group)) {
    //   // both members or bots can query group info
    // } else {
    //   // stranger
    //   throw Exception('Not a member of group: $group');
    // }

    // 1. do query
    bool ok1 = await messenger!.queryDocument(group);
    bool ok2 = await messenger!.queryMembers(group);
    return ok1 || ok2;
  }

  //
  //  EntityDataSource
  //

  // private
  Future<Meta?> getMeta(ID identifier) async =>
      await messenger?.facebook.getMeta(identifier);

  // private
  Future<Document?> getDocument(ID identifier, String? docType) async =>
      await messenger?.facebook.getDocument(identifier, docType);

  //
  //  Membership
  //

  // private
  Future<bool> isFounder(ID user, {required ID group}) async {
    CommonFacebook? facebook = messenger?.facebook;
    ID? founder = await facebook?.getFounder(group);
    if (founder != null) {
      return founder == user;
    }
    // check member's public key with group's meta.key
    Meta? gMeta = await facebook?.getMeta(group);
    assert(gMeta != null, 'failed to get meta for group: $group');
    Meta? mMeta = await facebook?.getMeta(user);
    assert(mMeta != null, 'failed to get meta for member: $user');
    return gMeta?.matchPublicKey(mMeta!.publicKey) ?? false;
  }

  // private
  Future<bool> isOwner(ID user, {required ID group}) async {
    ID? owner = await messenger?.facebook.getOwner(group);
    if (owner != null) {
      return owner == user;
    }
    if (group.type == EntityType.kGroup ) {
      // this is a polylogue
      return await isFounder(user, group: group);
    }
    throw Exception('only Polylogue so far');
  }

  // private
  Future<bool> isMember(ID user, {required ID group}) async {
    List<ID>? members = await messenger?.facebook.getMembers(group);
    return members?.contains(user) ?? false;
  }

  // private
  Future<bool> isAdministrator(ID user, {required ID group}) async {
    AccountDBI? db = messenger?.facebook.database;
    List<ID>? admins = await db?.getAdministrators(group: group);
    return admins?.contains(user) ?? false;
  }

  // private
  Future<bool> isAssistant(ID user, {required ID group}) async {
    List<ID>? bots = await messenger?.facebook.getAssistants(group);
    return bots?.contains(user) ?? false;
  }

  //
  //  Group Bots
  //

  // private
  Future<List<ID>> getAssistants({required ID group}) async {
    return await messenger?.facebook.getAssistants(group) ?? [];
  }

  // private
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async {
    AccountDBI? db = messenger?.facebook.database;
    return await db?.saveAssistants(bots, group: group) ?? false;
  }

  //
  //  Administrators
  //

  // private
  Future<List<ID>> getAdministrators({required ID group}) async {
    AccountDBI? db = messenger?.facebook.database;
    List<ID>? members = await db?.getAdministrators(group: group);
    return members == null ? [] : [...members];  // clone
  }

  // private
  Future<bool> saveAdministrators(List<ID> members, {required ID group}) async {
    AccountDBI? db = messenger?.facebook.database;
    return await db?.saveAdministrators(members, group: group) ?? false;
  }

  //
  //  Members
  //

  // private
  Future<List<ID>> getMembers({required ID group}) async {
    List<ID>? members = await messenger?.facebook.getMembers(group);
    return members == null ? [] : [...members];  // clone
  }

  // private
  Future<bool> saveMembers(List<ID> members, {required ID group}) async {
    AccountDBI? db = messenger?.facebook.database;
    return await db?.saveMembers(members, group: group) ?? false;
  }

  // private
  Future<bool> addMember(ID member, {required ID group}) async {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = await getMembers(group: group);
    int pos = allMembers.indexOf(member);
    if (pos >= 0) {
      // already exists
      return false;
    }
    allMembers.add(member);
    return await saveMembers(allMembers, group: group);
  }

  // private
  Future<bool> removeMember(ID member, {required ID group}) async {
    assert(member.isUser && group.isGroup, "ID error: $member, $group");
    List<ID> allMembers = await getMembers(group: group);
    int pos = allMembers.indexOf(member);
    if (pos < 0) {
      // not exists
      return false;
    }
    allMembers.removeAt(pos);
    return await saveMembers(allMembers, group: group);
  }

  // private
  Future<List<ID>> addMembers(List<ID> newMembers, {required ID group}) async {
    List<ID> members = await getMembers(group: group);
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

  // private
  Future<List<ID>> removeMembers(List<ID> outMembers, {required ID group}) async {
    List<ID> members = await getMembers(group: group);
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
