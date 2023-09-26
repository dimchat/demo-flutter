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
import 'package:lnc/lnc.dart';

import 'ease.dart';

///  Invite Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. add new member(s) to the group
///      2. any member can invite new member
class InviteGroupCommandProcessor extends EaseGroupCommandProcessor {
  InviteGroupCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is InviteCommand, 'invite command error: $content');
    GroupCommand command = content as GroupCommand;

    // 0. check command
    Pair<ID?, List<Content>?> expPair = await checkCommandExpired(command, rMsg);
    ID? group = expPair.first;
    if (group == null) {
      // ignore expired command
      return expPair.second ?? [];
    }
    Pair<List<ID>, List<Content>?> memPair = await checkCommandMembers(command, rMsg);
    List<ID> inviteList = memPair.first;
    if (inviteList.isEmpty) {
      // command error
      return memPair.second ?? [];
    }

    // 1. check group
    Triplet<ID?, List<ID>, List<Content>?> trip = await checkGroupMembers(command, rMsg);
    ID? owner = trip.first;
    List<ID> members = trip.second;
    if (owner == null || members.isEmpty) {
      return trip.third ?? [];
    }
    String text;

    ID sender = rMsg.sender;
    bool isMember = members.contains(sender);

    // 2. check permission
    if (!isMember) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to invite member into group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. accept it
    if (await acceptCommand(command, rMsg)) {
      Log.info('accepted "reset" command for group: $group');
    } else {
      Log.error('failed to accept "reset" command for group: $group');
    }

    // no need to response this group command
    return [];
  }

}
