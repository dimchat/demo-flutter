import 'helper/sqlite.dart';
import 'entity.dart';


ID _extractMember(ResultSet resultSet, int index) {
  String? member = resultSet.getString('member');
  return ID.parse(member)!;
}

class _MemberDB extends DataTableHandler<ID> {
  _MemberDB() : super(EntityDatabase(), _extractMember);

  static const String _table = EntityDatabase.tMember;
  static const List<String> _selectColumns = ["member"];
  static const List<String> _insertColumns = ["gid", "member"];

  Future<List<ID>> getMembers(ID group) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.string);
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  Future<bool> saveMembers(List<ID> members, ID group) async {
    // TODO: implement saveMembers
    Log.error('implement saveMembers: $group, $members');
    return false;
  }

  Future<bool> addMember(ID member, {required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.string);
    cond.addCondition(SQLConditions.kAnd, left: 'member', comparison: '=', right: member.string);
    List<ID> results = await select(_table, columns: _selectColumns, conditions: cond);
    if (results.isNotEmpty) {
      return false;
    }
    List values = [member.string, group.string];
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  Future<bool> removeMember(ID member, {required ID group}) async {
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.string);
    cond.addCondition(SQLConditions.kAnd, left: 'member', comparison: '=', right: member.string);
    return await delete(_table, conditions: cond) > 0;
  }

}


class GroupTable implements GroupDBI {
  GroupTable() : _memberTable = _MemberDB();

  final _MemberDB _memberTable;

  @override
  Future<ID?> getFounder({required ID group}) async {
    // TODO: implement getFounder
    Log.error('implement getFounder: $group');
    return null;
  }

  @override
  Future<ID?> getOwner({required ID group}) async {
    // TODO: implement getOwner
    Log.error('implement getOwner: $group');
    return null;
  }

  @override
  Future<List<ID>> getMembers({required ID group}) async =>
      await _memberTable.getMembers(group);

  @override
  Future<bool> saveMembers(List<ID> members, {required ID group}) async =>
      await _memberTable.saveMembers(members, group);

  @override
  Future<bool> addMember(ID member, {required ID group}) async =>
      await _memberTable.addMember(member, group: group);

  @override
  Future<bool> removeMember(ID member, {required ID group}) async =>
      await _memberTable.removeMember(member, group: group);

  @override
  Future<List<ID>> getAssistants({required ID group}) async {
    // TODO: implement getAssistants
    Log.error('implement getAssistants: $group');
    return [];
  }

  @override
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async {
    // TODO: implement saveAssistants
    Log.error('implement saveAssistants: $group, $bots');
    return false;
  }

  @override
  Future<bool> removeGroup({required ID group}) async {
    // TODO: implement removeGroup
    Log.error('implement removeGroup: $group');
    return false;
  }

}
