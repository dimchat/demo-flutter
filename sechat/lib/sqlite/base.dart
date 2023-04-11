import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SQLiteDB {
  SQLiteDB({this.version = 1});

  final int version;

  Future<String> _path(String name, {String? directory}) async {
    directory ??= await getDatabasesPath();
    if (name.endsWith('.db')) {
      return join(directory, name);
    } else {
      return join(directory, '$name.db');
    }
  }

  Future<Database> create(String filename, String? directory,
      {required String sql}) async {
    String filepath = await _path(filename, directory: directory);
    return openDatabase(filepath, version: version,
        onCreate: (Database db, int version) => db.execute(sql));
  }

  Future<void> delete(String filename, String? directory) async {
    String filepath = await _path(filename, directory: directory);
    deleteDatabase(filepath);
  }

}
