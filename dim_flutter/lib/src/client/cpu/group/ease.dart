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

class EaseGroupCommandProcessor extends GroupCommandProcessor {
  EaseGroupCommandProcessor(super.facebook, super.messenger);

  Future<InstantMessage?> _decryptMessage(Object? application) async {
    ReliableMessage? rMsg = ReliableMessage.parse(application);
    if (rMsg == null) {
      assert(false, 'failed to parse message: $application');
      return null;
    }
    SecureMessage? sMsg = await messenger?.verifyMessage(rMsg);
    if (sMsg == null) {
      assert(false, 'failed to verify message: $rMsg');
      return null;
    }
    return await messenger?.decryptMessage(sMsg);
  }

  bool _doInvite(List<ID> allMembers, InviteCommand content,
      {required ID sender}) {
    List<ID>? inviteList = GroupCommandHelper.getMembersFromCommand(content);
    assert(inviteList.isNotEmpty, 'failed to get members from command: $content');
    if (!allMembers.contains(sender)) {
      // only the members can invite new member
      assert(false, 'cannot invite members: $sender');
      return false;
    }
    for (ID item in inviteList) {
      if (allMembers.contains(item)) {
        // already exist
      } else {
        allMembers.add(item);
      }
    }
    return true;
  }

  Future<bool> _refreshMembers(ID group, List<ID> members, List applications) async {
    assert(members.isNotEmpty, 'members should not empty: $group');
    ID? owner = await getOwner(group);
    if (owner == null) {
      assert(false, 'group not ready: $group');
      return false;
    }
    List<ID> allMembers = [...members];
    // decrypt messages from applications
    InstantMessage? iMsg;
    Content? content;
    ID? gid;
    for (Object? item in applications) {
      iMsg = await _decryptMessage(item);
      if (iMsg == null) {
        assert(false, 'failed to parse decrypt message: $iMsg');
        continue;
      }
      content = iMsg.content;
      gid = content.group;
      if (gid != group) {
        assert(false, 'content group error: $group, $content');
        continue;
      }
      if (content is InviteCommand) {
        _doInvite(allMembers, content, sender: iMsg.sender);
      } else {
        assert(false, 'group command error: $content');
      }
    }
    // save new members
    return await saveMembers(group, allMembers);
  }

  //
  //  main
  //

  Future<bool> acceptCommand(GroupCommand content, ReliableMessage rMsg) async {
    ID? group = content.group;
    User? user = await facebook?.currentUser;
    if (group == null || user == null) {
      assert(false, 'should not happen');
      return false;
    }
    ID? owner = await getOwner(group);
    List<ID> admins = await getAdministrators(group);
    bool iCanReset = owner == user.identifier || admins.contains(user.identifier);

    List<ID> members;
    List applications;
    if (content is ResetCommand) {
      // if here is a 'reset' command, it must from the owner/administrator,
      // so just save it and refresh all members;
      // and the old 'reset' command (if exists) will be overwritten,
      // includes its 'applications'.
      members = GroupCommandHelper.getMembersFromCommand(content);
      assert(members.isNotEmpty, 'failed to get members from command: $content');
      applications = rMsg['applications'] ?? [];
      if (iCanReset) {
        // the owner/admin can build 'reset' command,
        // so no needs to save the 'reset' command here.
      } else {
        await saveResetCommandMessage(group, content, rMsg);
      }
    } else if (iCanReset) {
      // the owner/admins can build 'reset' command,
      // so get members from local storage, and
      // take this message as a new application
      members = await getMembers(group);
      applications = [rMsg.toMap()];
    } else {
      // here is an 'invite' group command,
      // try to load 'reset' command from local storage first,
      // and merge this command as a new application
      Pair<ResetCommand?, ReliableMessage?> pair = await getResetCommandMessage(group);
      ResetCommand? cmd = pair.first;
      ReliableMessage? msg = pair.second;
      if (cmd == null || msg == null) {
        // FIXME: 'reset' command not found?
        //        query from the owner/admins
        members = await getMembers(group);
        applications = [rMsg.toMap()];
      } else {
        // old 'reset' command found, take the initialized members in it,
        // merge this command to the exist applications;
        // and save the 'reset' command with new 'applications'.
        members = GroupCommandHelper.getMembersFromCommand(cmd);
        applications = msg['applications'] ?? [];
        applications.add(rMsg.toMap());
        msg['applications'] = applications;
        await saveResetCommandMessage(group, cmd, msg);
      }
    }
    // now the initialized members got, and maybe followed with some
    // applications, try to refresh the local members
    return await _refreshMembers(group, members, applications);
  }

}
