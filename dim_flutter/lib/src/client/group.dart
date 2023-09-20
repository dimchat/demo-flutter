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
import 'package:lnc/lnc.dart' show Log;

import '../models/chat_group.dart';
import 'group_ds.dart';

class GroupManager {
  factory GroupManager() => _instance;
  static final GroupManager _instance = GroupManager._internal();
  GroupManager._internal() {
    _delegate = null;
  }

  // getter/setter
  ClientMessenger? messenger;

  // group data source
  GroupDelegate? _delegate;

  GroupDelegate get dataSource {
    GroupDelegate? ds = _delegate;
    if (ds == null) {
      CommonFacebook? facebook = messenger?.facebook;
      assert(facebook != null, 'facebook should not empty here');
      _delegate = ds = GroupDelegate(facebook!, messenger!);
    }
    return ds;
  }

  // private
  Future<User?> get currentUser async => await messenger?.facebook.currentUser;

  Future<ID?> createGroup({required List<ID> members}) async {
    if (members.length < 2) {
      assert(false, 'not enough members: $members');
      return null;
    }
    // 0. get current user
    ClientFacebook? barrack = messenger?.facebook as ClientFacebook?;
    User? user = await barrack?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return null;
    }
    // 1. check founder/owner
    AccountDBI db = barrack!.database;
    ID me = user.identifier;
    int pos = members.indexOf(me);
    if (pos < 0) {
      // put myself in the first position
      members.insert(0, me);
    } else if (pos > 0) {
      // move me to the front
      members.removeAt(pos);
      members.insert(0, me);
    }
    // 2. build group name
    String groupName = await GroupInfo.buildGroupName(members);
    // 3. create group
    Register register = Register(db);
    ID group = await register.createGroup(me, name: groupName);
    Log.info('new group ID: $group');
    if (await resetGroupMembers(group, members)) {
      Log.info('created group $group with ${members.length} members');
      return group;
    }
    Log.error('failed to created group $group with ${members.length} members');
    return null;
  }

  ///  Reset group members
  ///
  /// @param newMembers - new member ID list
  /// @return true on success
  Future<bool> resetGroupMembers(ID group, List<ID> newMembers) async {
    assert(group.isGroup && newMembers.isNotEmpty, 'params error: $group, $newMembers');
    GroupDelegate delegate = dataSource;

    ID me = (await currentUser)!.identifier;

    if (await delegate.isOwner(newMembers.first, group: group)) {
      // member list OK
    } else {
      throw Exception("Group owner must be the first member: $group");
    }

    // 0. check permission
    if (me == newMembers.first || await delegate.isAdministrator(me, group: group)) {
      // only the owner or admin can reset group members
    } else {
      // not an admin/owner
      throw Exception('Cannot reset members of group: $group');
    }

    // 1. update local members
    List<ID> oldMembers = await delegate.getMembers(group);
    List<ID> expelList = [];
    for (ID item in oldMembers) {
      if (!newMembers.contains(item)) {
        expelList.add(item);
      }
    }
    if (await delegate.saveMembers(newMembers, group: group)) {
      // OK
    } else {
      throw Exception('Failed to update members of group: $group');
    }

    List<ID> bots = await delegate.getAssistants(group);
    Meta? meta = await delegate.getMeta(group);
    assert(meta != null, 'meta not found: $group');
    Document? doc = await delegate.getDocument(group, "*");
    assert(doc != null, 'document not found: $group');

    // NOTICE: group assistants (bots) can help the members to redirect messages
    //
    //      if members.length < 16,
    //          means it is a small polylogue group, let the members to split
    //          and send group messages by themself, this can keep the group
    //          more secretive because no one else can know the group ID even.
    //      else,
    //          set 'assistants' in the bulletin document to tell all members
    //          that they can let the group bot to do the job for them.
    //
    // TODO: check for group assistants

    // 2. send 'meta/document' command
    Command command = doc == null
        ? MetaCommand.response(group, meta!)
        : DocumentCommand.response(group, meta, doc);
    await _sendCommand(command, members: bots);              // to all assistants

    // 3. send 'reset' command
    command = GroupCommand.reset(group, members: newMembers);
    await _sendCommand(command, members: bots);              // to all assistants
    await _sendCommand(command, members: newMembers);        // to new members
    await _sendCommand(command, members: expelList);         // to expelled members

    return true;
  }

  ///  Invite new members to this group
  ///
  /// @param newMembers - new member ID list to be added
  /// @return true on success
  Future<bool> inviteGroupMembers(ID group, List<ID> newMembers) async {
    assert(group.isGroup && newMembers.isNotEmpty, 'params error: $group, $newMembers');
    GroupDelegate delegate = dataSource;

    ID me = (await currentUser)!.identifier;
    List<ID> oldMembers = await delegate.getMembers(group);

    if (await delegate.isAdministrator(me, group: group) ||
        await delegate.isOwner(me, group: group)) {
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
    if (await delegate.isMember(me, group: group)) {
      // ordinary member
    } else {
      // not a member
      throw Exception('Cannot invite member into group: $group');
    }

    // 1. update local members
    List<ID> members = await delegate.addMembers(newMembers, group: group);

    List<ID> bots = await delegate.getAssistants(group);
    Meta? meta = await delegate.getMeta(group);
    assert(meta != null, 'meta not found: $group');
    Document? doc = await delegate.getDocument(group, "*");
    assert(doc != null, 'document not found: $group');

    // 2. send 'meta/document' command
    Command command = doc == null
        ? MetaCommand.response(group, meta!)
        : DocumentCommand.response(group, meta, doc);
    await _sendCommand(command, members: bots);              // to all assistants
    await _sendCommand(command, members: newMembers);        // to new members

    // 3. send 'invite' command
    command = GroupCommand.invite(group, members: newMembers);
    await _sendCommand(command, members: bots);              // to all assistants
    await _sendCommand(command, members: oldMembers);        // to old members
    command = GroupCommand.invite(group, members: members);
    await _sendCommand(command, members: newMembers);        // to new members

    return true;
  }

  ///  Quit from this group
  ///
  /// @return true on success
  Future<bool> quitGroup(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    GroupDelegate delegate = dataSource;

    ID me = (await currentUser)!.identifier;

    // 0. check permission
    if (await delegate.isAdministrator(me, group: group)) {
      throw Exception('Administrator cannot quit from group: $group');
    } else if (await delegate.isOwner(me, group: group)) {
      throw Exception('Owner cannot quit from group: $group');
    } else if (await delegate.isMember(me, group: group)) {
      // ordinary member
    } else {
      // not a member
      assert(false, 'Not a member of group: $group');
    }

    List<ID> bots = await delegate.getAssistants(group);
    List<ID> members = await delegate.getMembers(group);

    // 1. update local storage
    bool ok = false;
    if (members.remove(me)) {
      ok = await delegate.saveMembers(members, group: group);
      //} else {
      //    // not a member now
      //    return false;
    }

    // 2. send 'quit' command
    Command command = GroupCommand.quit(group);
    await _sendCommand(command, members: bots);     // to assistants
    await _sendCommand(command, members: members);  // to new members

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

  // private
  Future<void> _sendCommand(Command content, {required List<ID> members}) async {
    ID? me = (await currentUser)?.identifier;
    for (ID item in members) {
      if (item == me) {
        // skip cycled message
        continue;
      }
      await messenger?.sendContent(content, sender: me, receiver: item);
    }
  }

  //
  //  Sending group message
  //

  ///  Send group message content
  ///
  /// @param content  - group message content
  /// @param sender
  /// @param receiver - group ID
  /// @param priority
  /// @return
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content,
      {required ID? sender, required ID receiver, int priority = 0}) async {
    // 0. check sender, receiver
    if (sender == null) {
      User? user = await currentUser;
      assert(user != null, 'failed to get current user');
      sender = user!.identifier;
    }
    assert(receiver == content.group, 'group ID error: $receiver, ${content.group}');
    ID group = receiver;
    // 1. create message
    Envelope envelope = Envelope.create(sender: sender, receiver: group);
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    // FIXME: expose 'sn' before 'respondReceipt()' upgraded
    iMsg['sn'] = content.sn;
    // 2. check group bots
    GroupDelegate delegate = dataSource;
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isEmpty) {
      // no 'assistants' found in group's bulletin document?
      // split group messages and send to all members one by one
      int ok = await _splitGroupMessage(group, iMsg, priority: priority);
      Log.info('split message for group: $group, $ok');
      return Pair(iMsg, null);
    } else {
      // forward the group message to any bot
      ID prime = bots[0];
      ReliableMessage? rMsg = await _forwardGroupMessage(iMsg, bot: prime, priority: priority);
      return Pair(iMsg, rMsg);
    }
  }

  Future<ReliableMessage?> _forwardGroupMessage(InstantMessage iMsg, {required ID bot, required int priority}) async {
    // NOTICE: because group assistant (bot) cannot be a member of the group, so
    //         if you want to send a group command to any assistant, you must
    //         set the bot ID as 'receiver' and set the group ID in content;
    //         this means you must send it to the bot directly.
    assert(iMsg.containsKey('group') == false, 'should not happen');
    ID group = iMsg.receiver;
    assert(group.isGroup, 'group ID error: $group');

    // group bots designated, let group bot to split the message, so
    // here must expose the group ID; this will cause the client to
    // use a "user-to-group" encrypt key to encrypt the message content,
    // this key will be encrypted by each member's public key, so
    // all members will received a message split by the group bot,
    // but the group bots cannot decrypt it.
    iMsg.setString('group', group);

    // 1. pack message
    SecureMessage? sMsg = await messenger?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message for group: $group');
      return null;
    }
    ReliableMessage? rMsg = await messenger?.signMessage(sMsg);
    if (rMsg == null) {
      assert(false, 'failed to sign message: ${iMsg.sender} => $group');
      return null;
    }

    // 2. forward the group message to any bot
    Content content = ForwardContent.create(forward: rMsg);
    Pair? pair = await messenger?.sendContent(content, sender: null, receiver: bot, priority: priority);
    if (pair?.second == null) {
      assert(false, 'failed to forward message for group: $group');
      return null;
    }

    // OK, return the forwarding message
    return rMsg;
  }

  /// split group messages and send to all members one by one
  Future<int> _splitGroupMessage(ID group, InstantMessage iMsg, {required int priority}) async {
    GroupDelegate delegate = dataSource;
    // get members
    List<ID> allMembers = await delegate.getMembers(group);
    if (allMembers.isEmpty) {
      Log.warning('group empty: $group');
      return -1;
    }
    ID sender = iMsg.sender;
    int success = 0;
    // split messages
    InstantMessage? item;
    ReliableMessage? res;
    for (ID member in allMembers) {
      if (member == sender) {
        // ignore cycled message
        continue;
      }
      Log.info('split group message for member: $member, group: $group');
      Map info = iMsg.copyMap(false);
      // replace 'receiver' with member ID
      info['receiver'] = member.toString();
      item = InstantMessage.parse(info);
      if (item == null) {
        assert(false, 'failed to repack message: $member');
        continue;
      }
      res = await messenger?.sendInstantMessage(item, priority: priority);
      if (res == null) {
        assert(false, 'failed to send message: $member');
        continue;
      }
      success += 1;
    }
    // done!
    return success;
  }

}
