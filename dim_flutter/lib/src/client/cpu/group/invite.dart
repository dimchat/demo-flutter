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

///  Invite Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. add new member(s) to the group
///      2. any member can invite new member
///      3. invited by ordinary member should be reviewed by owner/administrator
class LooseInviteCommandProcessor extends ResetCommandProcessor {
  LooseInviteCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is InviteCommand, 'invite command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    if (await isCommandExpired(command)) {
      // ignore expired command
      return [];
    }
    ID group = command.group!;
    List<ID> inviteList = getMembersFromCommand(command);
    if (inviteList.isEmpty) {
      return respondReceipt('Command error.', rMsg, group: group, extra: {
        'template': 'Invite list is empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 1. check group
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner == null || members.isEmpty) {
      // TODO: query group members?
      return respondReceipt('Group empty.', rMsg, group: group, extra: {
        'template': 'Group empty: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 2. check permission
    ID sender = rMsg.sender;
    if (!members.contains(sender)) {
      return respondReceipt('Permission denied.', rMsg, group: group, extra: {
        'template': 'Not allowed to invite member into group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. do invite
    Pair<List<ID>, List<ID>> pair = _calculateInvited(members: members, inviteList: inviteList);
    List<ID> newMembers = pair.first;
    List<ID> addedList = pair.second;
    if (addedList.isEmpty) {
      // maybe those users are already become members,
      // but if it can still receive an 'invite' command here,
      // we should respond the sender with the newest membership again.
      bool ok = await sendResetCommand(group: group, members: newMembers, receiver: sender);
      assert(ok, 'failed to send "reset" command for group: $group => $sender');
    } else if (await saveMembers(newMembers, group)) {
      command['added'] = ID.revert(addedList);
    }

    // no need to response this group command
    return [];
  }

  Pair<List<ID>, List<ID>> _calculateInvited({required List<ID> members, required List<ID> inviteList}) {
    List<ID> newMembers = [...members];
    List<ID> addedList = [];
    for (ID item in inviteList) {
      if (newMembers.contains(item)) {
        continue;
      }
      newMembers.add(item);
      addedList.add(item);
    }
    return Pair(newMembers, addedList);
  }

}
