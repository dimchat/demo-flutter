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
import 'shared.dart';

class GroupManager {
  factory GroupManager() => _instance;
  static final GroupManager _instance = GroupManager._internal();
  GroupManager._internal() {
    _delegate = null;
  }

  // NOTICE: group assistants (bots) can help the members to redirect messages
  //
  //      if members.length < kPolylogueLimit,
  //          means it is a small polylogue group, let the members to split
  //          and send group messages by themself, this can keep the group
  //          more secretive because no one else can know the group ID even.
  //      else,
  //          set 'assistants' in the bulletin document to tell all members
  //          that they can let the group bot to do the job for them.
  //
  int kPolylogueLimit = 16;

  // group data source
  GroupDelegate? _delegate;

  GroupDelegate get dataSource {
    GroupDelegate? ds = _delegate;
    if (ds == null) {
      GlobalVariable shared = GlobalVariable();
      CommonFacebook barrack = shared.facebook;
      CommonMessenger? transceiver = shared.messenger;
      _delegate = ds = GroupDelegate(barrack, transceiver!);
    }
    return ds;
  }

  ClientFacebook get facebook => GlobalVariable().facebook;
  ClientMessenger? get messenger => GlobalVariable().messenger;

  AccountDBI get adb => facebook.database;

  Future<User?> get currentUser async => await facebook.currentUser;

  //
  //  Group Command Delegates
  //

  GroupCommandHelper? _helper;
  GroupHistoryBuilder? _builder;

  GroupCommandHelper get helper {
    GroupCommandHelper? delegate = _helper;
    if (delegate == null) {
      _helper = delegate = createGroupCommandHelper();
    }
    return delegate;
  }
  /// override for customized helper
  GroupCommandHelper createGroupCommandHelper() => GroupCommandHelper(facebook, messenger!);

  GroupHistoryBuilder get builder {
    GroupHistoryBuilder? delegate = _builder;
    if (delegate == null) {
      _builder = delegate = createGroupHistoryBuilder();
    }
    return delegate;
  }
  /// override for customized builder
  GroupHistoryBuilder createGroupHistoryBuilder() => GroupHistoryBuilder(helper);

  /// Create new group with members
  Future<ID?> createGroup({required List<ID> members}) async {
    if (members.length < 2) {
      assert(false, 'not enough members: $members');
      return null;
    }
    //
    //  0. get current user
    //
    User? user = await currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return null;
    }
    ID founder = user.identifier;
    //
    //  1. check founder/owner
    //
    int pos = members.indexOf(founder);
    if (pos < 0) {
      // put myself in the first position
      members.insert(0, founder);
    } else if (pos > 0) {
      // move me to the front
      members.removeAt(pos);
      members.insert(0, founder);
    }
    //
    //  2. create group with name
    //
    Register register = Register(adb);
    String groupName = await GroupInfo.buildGroupName(members);
    ID group = await register.createGroup(founder, name: groupName);
    Log.info('new group: $group ($groupName), founder: $founder');
    //
    //  3. upload meta+document to neighbor station(s)
    //  DISCUSS: should we let the neighbor stations know the group info?
    //
    Meta? meta = await dataSource.getMeta(group);
    Document? doc = await dataSource.getDocument(group, '*');
    Command content;
    if (doc != null) {
      content = DocumentCommand.response(group, meta, doc);
      _sendCommand(content, [Station.kAny]);            // to neighbor(s)
    } else if (meta != null) {
      content = MetaCommand.response(group, meta);
      _sendCommand(content, [Station.kAny]);            // to neighbor(s)
    } else {
      assert(false, 'failed to get group info: $group');
    }
    //
    //  4. create & broadcast 'reset' group command with new members
    //
    if (await resetGroupMembers(group, members)) {
      Log.info('created group $group with ${members.length} members');
    } else {
      Log.error('failed to created group $group with ${members.length} members');
    }
    return group;
  }

  // DISCUSS: should we let the neighbor stations know the group info?
  //      (A) if we do this, it can provide a convenience that,
  //          when someone receive a message from an unknown group,
  //          it can query the group info from the neighbor immediately;
  //          and its potential risk is that anyone not in the group can also
  //          know the group info (only the group ID, name, and admins, ...)
  //      (B) but, if we don't let the station knows it,
  //          then we must shared the group info with our members themself;
  //          and if none of them is online, you cannot get the newest info
  //          info immediately until someone online again.

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

    // check expelled members
    List<ID> oldMembers = await delegate.getMembers(group);
    List<ID> expelList = [];
    for (ID item in oldMembers) {
      if (!newMembers.contains(item)) {
        expelList.add(item);
      }
    }

    // 1. build 'reset' command
    Pair<ResetCommand?, ReliableMessage?> pair = await builder.buildResetCommand(group, newMembers);
    ResetCommand? reset = pair.first;
    ReliableMessage? message = pair.second;
    if (reset == null || message == null) {
      assert(false, 'failed to build "reset" command for group: $group');
      return false;
    }

    // 2. save 'reset' command, and update new members
    if (!await helper.saveGroupHistory(group, reset, message)) {
      throw Exception('Failed to save "reset" command for group: $group');
    } else if (!await delegate.saveMembers(newMembers, group: group)) {
      throw Exception('Failed to update members of group: $group');
    } else {
      Log.info('group members updated: $group, ${newMembers.length}');
    }

    // 3. forward all group history
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    ForwardContent forward = ForwardContent.create(secrets: messages);

    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // let the group bots know the newest member ID list,
      // so they can split group message correctly for us.
      _sendCommand(forward, bots);                      // to all assistants
      return true;
    }
    // group bots not exist,
    // send the command to all members
    _sendCommand(forward, newMembers);                  // to all assistants
    _sendCommand(forward, expelList);                   // to all assistants
    return true;
  }

  ///  Expel members from this group
  ///
  /// @param expelMembers - members to be removed
  /// @return true on success
  Future<bool> expelGroupMembers(ID group, List<ID> expelMembers) async {
    assert(group.isGroup && expelMembers.isNotEmpty, 'params error: $group, $expelMembers');
    GroupDelegate delegate = dataSource;

    ID me = (await currentUser)!.identifier;
    List<ID> oldMembers = await delegate.getMembers(group);

    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);

    // 0. check permission
    bool canReset = isOwner || isAdmin;
    if (canReset) {
      // You are the owner/admin, then
      // remove the members and 'reset' the group
      List<ID> members = [...oldMembers];
      for (ID item in expelMembers) {
        members.remove(item);
      }
      return await resetGroupMembers(group, members);
    }

    // not an admin/owner
    throw Exception('Cannot expel members from group: $group');
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

    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);

    // 0. check permission
    bool canReset = isOwner || isAdmin;
    if (canReset) {
      // You are the owner/admin, then
      // append new members and 'reset' the group
      List<ID> members = [...oldMembers];
      for (ID item in newMembers) {
        if (!members.contains(item)) {
          members.add(item);
        }
      }
      return await resetGroupMembers(group, members);
    }

    bool isMember = await delegate.isMember(me, group: group);
    if (isMember) {
      // ordinary member
    } else {
      // not a member
      throw Exception('Cannot invite member into group: $group');
    }

    // 1. build 'invite' command
    InviteCommand content = GroupCommand.invite(group, members: newMembers);
    ReliableMessage? rMsg = await _packGroupMessage(content, me);
    if (rMsg == null) {
      assert(false, 'failed to sign message: $me => $group');
      return false;
    }

    // 2. save 'invite' command
    if (!await helper.saveGroupHistory(group, content, rMsg)) {
      throw Exception('Failed to save "invite" command for group: $group');
    }
    ForwardContent forward = ForwardContent.create(forward: rMsg);

    // 3. forward 'invite'
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // let the group bots know the newest member ID list,
      // so they can split group message correctly for us.
      _sendCommand(forward, bots);                      // to all assistants
      return true;
    }
    // forward 'invite' to old members
    _sendCommand(forward, oldMembers);                  // to old members
    // forward all group history to new members
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    forward = ForwardContent.create(secrets: messages);
    _sendCommand(forward, newMembers);                  // to new members
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

    // 1. update local storage
    List<ID> members = await delegate.getMembers(group);
    bool ok = members.remove(me) && await delegate.saveMembers(members, group: group);

    // 2. build 'quit' command
    Command content = GroupCommand.quit(group);
    ForwardContent? forward = await _packGroupCommand(content, me);
    if (forward == null) {
      assert(false, 'failed to pack "quit" command for group: $group');
      return false;
    }

    // 3. forward 'quit' command
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isEmpty) {
      // group bots not exist,
      // send the command to all members
      _sendCommand(forward, members);                   // to new members
    } else {
      // let the group bots know the newest member ID list,
      // so they can split group message correctly for us.
      _sendCommand(forward, bots);                      // to new members
    }

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

  Future<bool> _sendCommand(Content content, List<ID> members) async {
    // assert(content.group != null, 'group command error: $content');
    User? user = await currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    // send group command to members directly
    ForwardContent? forward = await _packGroupCommand(content, me);
    if (forward == null) {
      assert(false, 'failed to pack group command: $content');
      return false;
    }
    for (ID item in members) {
      if (item == me) {
        // skip cycled message
        continue;
      }
      messenger?.sendContent(forward, sender: me, receiver: item);
    }
    return true;
  }

  Future<ReliableMessage?> _packGroupMessage(Content content, ID sender) async {
    Envelope env = Envelope.create(sender: sender, receiver: ID.kAnyone);
    InstantMessage iMsg = InstantMessage.create(env, content);
    iMsg['group'] = content['group'];  // expose group ID
    SecureMessage? sMsg = await messenger?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt group message: $env');
      return null;
    }
    ReliableMessage? rMsg = await messenger?.signMessage(sMsg);
    if (rMsg == null) {
      assert(false, 'failed to sign group message: $env');
      return null;
    }
    return rMsg;
  }
  Future<ForwardContent?> _packGroupCommand(Content content, ID sender) async {
    ReliableMessage? rMsg = await _packGroupMessage(content, sender);
    if (rMsg == null) {
      assert(false, 'failed to sign group message: ${content.group}');
      return null;
    }
    return ForwardContent.create(forward: rMsg);
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
      ReliableMessage? rMsg = await _forwardGroupMessage(group, iMsg, bot: prime, priority: priority);
      return Pair(iMsg, rMsg);
    }
  }

  Future<ReliableMessage?> _forwardGroupMessage(ID group, InstantMessage iMsg, {required ID bot, required int priority}) async {
    // NOTICE: because group assistant (bot) cannot be a member of the group, so
    //         if you want to send a group command to any assistant, you must
    //         set the bot ID as 'receiver' and set the group ID in content;
    //         this means you must send it to the bot directly.
    assert(iMsg.containsKey('group') == false, 'should not happen');

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

    // 0. get members
    List<ID> allMembers = await delegate.getMembers(group);
    if (allMembers.isEmpty) {
      Log.warning('group empty: $group');
      return -1;
    }

    // 1. check file content
    Content content = iMsg.content;
    if (content is FileContent) {
      if (content.data != null/* && content.url == null*/) {
        SymmetricKey? key = await messenger?.getEncryptKey(iMsg);
        assert(key != null, 'failed to get msg key: '
            '${iMsg.sender} => ${iMsg.receiver}, ${iMsg['group']}');
        // call emitter to encrypt & upload file data before send out
        GlobalVariable shared = GlobalVariable();
        await shared.emitter.sendFileContent(iMsg, key!);
        // keep the password in content
        content.password = key;
      }
    }
    // expose 'sn' for receipts
    iMsg['sn'] = content.sn;

    ID sender = iMsg.sender;
    int success = 0;

    // 2. split messages
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

      // 3. send message
      res = await messenger?.sendInstantMessage(item, priority: priority);
      if (res == null) {
        Log.error('failed to send message: $member in group $group');
        continue;
      }
      success += 1;
    }
    // done!
    return success;
  }

}
