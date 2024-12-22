
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import 'group_admin.dart';
import 'group_member.dart';


class GroupCache implements GroupDBI {
  GroupCache() : _memberTable = MemberCache(), _adminCache = AdminCache();

  final MemberCache _memberTable;
  final AdminCache _adminCache;

  @override
  Future<ID?> getFounder({required ID group}) async {
    // TODO: implement getFounder
    Log.warning('implement getFounder: $group');
    return null;
  }

  @override
  Future<ID?> getOwner({required ID group}) async {
    // TODO: implement getOwner
    Log.warning('implement getOwner: $group');
    return null;
  }

  @override
  Future<List<ID>> getMembers({required ID group}) async =>
      await _memberTable.getMembers(group);

  @override
  Future<bool> saveMembers(List<ID> members, {required ID group}) async =>
      await _memberTable.saveMembers(members, group);

  Future<bool> addMember(ID member, {required ID group}) async =>
      await _memberTable.addMember(member, group: group);

  Future<bool> removeMember(ID member, {required ID group}) async =>
      await _memberTable.removeMember(member, group: group);

  @override
  Future<List<ID>> getAssistants({required ID group}) async {
    // TODO: implement getAssistants
    Log.warning('implement getAssistants: $group');
    return [];
  }

  @override
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async {
    // TODO: implement saveAssistants
    Log.warning('implement saveAssistants: $group, $bots');
    return false;
  }

  @override
  Future<List<ID>> getAdministrators({required ID group}) async =>
      await _adminCache.getAdministrators(group);

  @override
  Future<bool> saveAdministrators(List<ID> admins, {required ID group}) async =>
      await _adminCache.saveAdministrators(admins, group);

  Future<bool> addAdministrator(ID admin, {required ID group}) async =>
      await _adminCache.addAdministrator(admin, group: group);

  Future<bool> removeAdministrator(ID admin, {required ID group}) async =>
      await _adminCache.removeAdministrator(admin, group: group);

  Future<bool> removeGroup({required ID group}) async {
    // TODO: implement removeGroup
    Log.warning('implement removeGroup: $group');
    return false;
  }

}
