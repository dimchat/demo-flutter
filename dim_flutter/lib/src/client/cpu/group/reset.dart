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

///  Reset Group Command Processor
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
///      1. reset group members
///      2. only group owner or assistant can reset group members
class ResetGroupCommandProcessor extends EaseGroupCommandProcessor {
  ResetGroupCommandProcessor(super.facebook, super.messenger);

  @override
  Future<List<Content>> process(Content content, ReliableMessage rMsg) async {
    assert(content is ResetCommand, 'reset command error: $content');
    ResetCommand command = content as ResetCommand;

    // 0. check command
    Pair<ID?, List<Content>?> grpPair = await checkCommandExpired(command, rMsg);
    ID? group = grpPair.first;
    if (group == null) {
      // ignore expired command
      return grpPair.second ?? [];
    }
    Pair<List<ID>, List<Content>?> memPair = await checkCommandMembers(command, rMsg);
    List<ID> newMembers = memPair.first;
    if (newMembers.isEmpty) {
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
    List<ID> admins = await getAdministrators(group);
    bool isOwner = owner == sender;
    bool isAdmin = admins.contains(sender);

    // 2. check permission
    bool canReset = isOwner || isAdmin;
    if (!canReset) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to reset members of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.1. check owner
    if (newMembers[0] != owner) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Owner must be the first member of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }
    // 2.2. check admins
    bool expelAdmin = false;
    for (ID item in admins) {
      if (!newMembers.contains(item)) {
        expelAdmin = true;
        break;
      }
    }
    if (expelAdmin) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to expel administrator of group: \${ID}',
        'replacements': {
          'ID': group.toString(),
        }
      });
    }

    // 3. accept it
    if (await acceptCommand(content, rMsg)) {
      Log.info('accepted "reset" command for group: $group');
    } else {
      Log.error('failed to accept "reset" command for group: $group');
    }

    // no need to response this group command
    return [];
  }

}
