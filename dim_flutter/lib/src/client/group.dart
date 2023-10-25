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

import 'shared.dart';

class SharedGroupManager implements GroupDataSource {
  factory SharedGroupManager() => _instance;
  static final SharedGroupManager _instance = SharedGroupManager._internal();
  SharedGroupManager._internal();

  CommonFacebook get facebook => GlobalVariable().facebook;
  CommonMessenger? get messenger => GlobalVariable().messenger;

  //
  //  delegates
  //
  late final GroupDelegate _delegate = GroupDelegate(facebook, messenger!);
  late final GroupManager _manager = GroupManager(_delegate);
  late final AdminManager _adminManager = AdminManager(_delegate);
  late final GroupEmitter _emitter = GroupEmitter(_delegate);

  Future<String> buildGroupName(List<ID> members) async =>
      await _delegate.buildGroupName(members);

  //
  //  Entity DataSource
  //

  @override
  Future<Meta?> getMeta(ID group) async => await _delegate.getMeta(group);

  @override
  Future<List<Document>> getDocuments(ID group) async =>
      await _delegate.getDocuments(group);

  Future<Bulletin?> getBulletin(ID group) async => await _delegate.getBulletin(group);

  //
  //  Group DataSource
  //

  @override
  Future<ID?> getFounder(ID group) async => await _delegate.getFounder(group);

  @override
  Future<ID?> getOwner(ID group) async => await _delegate.getOwner(group);

  @override
  Future<List<ID>> getMembers(ID group) async => await _delegate.getMembers(group);

  @override
  Future<List<ID>> getAssistants(ID group) async =>
      await _delegate.getAdministrators(group);

  Future<List<ID>> getAdministrators(ID group) async =>
      await _delegate.getAdministrators(group);

  Future<bool> isOwner(ID user, {required ID group}) async =>
      await _delegate.isOwner(user, group: group);

  Future<bool> broadcastDocument(Document doc) async =>
      await _adminManager.broadcastDocument(doc as Bulletin);

  //
  //  Group Manage
  //

  /// Create new group with members
  Future<ID?> createGroup(List<ID> members) async =>
      await _manager.createGroup(members);

  ///  Update 'administrators' in bulletin document
  ///
  /// @param newAdmins - new administrator ID list
  /// @return true on success
  Future<bool> updateAdministrators(ID group, List<ID> newAdmins) async =>
      await _adminManager.updateAdministrators(group, newAdmins);

  ///  Reset group members
  ///
  /// @param newMembers - new member ID list
  /// @return true on success
  Future<bool> resetGroupMembers(ID group, List<ID> newMembers) async =>
      await _manager.resetMembers(group, newMembers);

  ///  Expel members from this group
  ///
  /// @param expelMembers - members to be removed
  /// @return true on success
  Future<bool> expelGroupMembers(ID group, List<ID> expelMembers) async {
    assert(group.isGroup && expelMembers.isNotEmpty, 'params error: $group, $expelMembers');

    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    List<ID> oldMembers = await _delegate.getMembers(group);

    bool isOwner = await _delegate.isOwner(me, group: group);
    bool isAdmin = await _delegate.isAdministrator(me, group: group);

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
  Future<bool> inviteGroupMembers(ID group, List<ID> newMembers) async =>
      await _manager.inviteMembers(group, newMembers);

  ///  Quit from this group
  ///
  /// @return true on success
  Future<bool> quitGroup(ID group) async => await _manager.quitGroup(group);

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
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    assert(iMsg.content.group != null, 'group message error: $iMsg');
    return await _emitter.sendInstantMessage(iMsg, priority: priority);
  }

}
