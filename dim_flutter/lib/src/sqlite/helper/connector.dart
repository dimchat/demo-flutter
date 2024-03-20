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
import 'package:pnf/dos.dart';
import 'package:sqflite/sqflite.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import '../../common/platform.dart';


///
///  SQLite Database Connector
///

class DatabaseConnector {
  DatabaseConnector({required this.name, this.directory, this.version,
    this.onConfigure,
    this.onCreate, this.onUpgrade, this.onDowngrade,
    this.onOpen});

  final String name;  // 'user.db'
  final String? directory;
  final int? version;

  final OnDatabaseConfigureFn? onConfigure;
  final OnDatabaseCreateFn? onCreate;
  final OnDatabaseVersionChangeFn? onUpgrade;
  final OnDatabaseVersionChangeFn? onDowngrade;
  final OnDatabaseOpenFn? onOpen;

  DBConnection? _connection;

  Future<String?> get path async {
    String? dir = directory;
    if (dir == null) {
      DevicePlatform.patchSQLite();
      dir = await getDatabasesPath();
      Log.debug('internal database: $name in $dir');
      return Paths.append(dir, name);
    } else if (DevicePlatform.isWeb) {
      return dir;
    }
    throw Exception('external database: $name in $dir');
  }

  Future<Database> _open(String path) async =>
      await openDatabase(path, version: version,
          onConfigure: onConfigure,
          onCreate: onCreate, onUpgrade: onUpgrade, onDowngrade: onDowngrade,
          onOpen: onOpen);

  Future<DBConnection?> get connection async {
    DBConnection? conn = _connection;
    if (conn == null) {
      String? filepath = await path;
      if (filepath != null) {
        Log.debug('opening database: $filepath');
        try {
          Database db = await _open(filepath);
          conn = _Connection(db);
          _connection = conn;
        } on DatabaseException catch (e) {
          Log.error('failed to open database: $e');
        }
      }
    }
    return conn;
  }

  void destroy() {
    DBConnection? conn = _connection;
    if (conn != null) {
      _connection = null;
      conn.close();
    }
  }

  static void createTable(Database db, String table,
      {required List<String> fields}) {
    String sql = SQLBuilder.buildCreateTable(table, fields: fields);
    DBLogger.output('createTable: $sql');
    db.execute(sql);
  }

  static void createIndex(Database db, String table,
      {required String name, required List<String> fields}) {
    String sql = SQLBuilder.buildCreateIndex(table, name: name, fields: fields);
    DBLogger.output('createIndex: $sql');
    db.execute(sql);
  }

  static void addColumn(Database db, String table,
      {required String name, required String type}) {
    String sql = SQLBuilder2.buildAddColumn(table, name: name, type: type);
    DBLogger.output('alterTable: $sql');
    db.execute(sql);
  }

}

class SQLBuilder2 {
  SQLBuilder2(String command) : _sb = StringBuffer(command);

  final StringBuffer _sb;

  static const String alter = "ALTER";

  @override
  String toString() => _sb.toString();

  void _append(String sub) {
    _sb.write(sub);
  }

  ///
  ///  ALTER TABLE table ADD COLUMN IF NOT EXISTS name type;
  ///
  static String buildAddColumn(String table,
      {required String name, required String type}) {
    SQLBuilder2 builder = SQLBuilder2(alter);
    builder._append(' TABLE ');
    builder._append(table);
    // builder._append(' ADD COLUMN IF NOT EXISTS ');
    builder._append(' ADD COLUMN ');
    builder._append(name);
    builder._append(' ');
    builder._append(type);
    return builder.toString();
  }

}

abstract class DBLogger {

  static const String kSqlTag    = '- SQL -';
  static const String kSqlColor  = '\x1B[94m';

  static final DefaultLogger logger = DefaultLogger();

  static int output(String msg) =>
      logger.output(msg, caller: logger.caller, tag: kSqlTag, color: kSqlColor);

}



class _Connection implements DBConnection {
  _Connection(this.database);

  final Database database;

  @override
  void close() {
    if (database.isOpen) {
      database.close();
    }
  }

  @override
  Statement createStatement() => _Statement(database);
}

class _Statement implements Statement {
  _Statement(this.database) : _sql = null, _resultSet = null;

  final Database database;

  String? _sql;
  ResultSet? _resultSet;

  @override
  void close() {
    ResultSet? set = _resultSet;
    if (set != null) {
      _resultSet = null;
      set.close();
    }
  }

  @override
  Future<ResultSet> executeQuery(String sql) async {
    if (_sql != null) {
      throw Exception('Redundant execution: $sql');
    }
    _sql = sql;
    DBLogger.output('executeQuery: $sql');
    return _ResultSet(await database.rawQuery(sql));
  }

  @override
  Future<int> executeInsert(String sql) async {
    if (_sql != null) {
      throw Exception('Redundant execution: $sql');
    }
    _sql = sql;
    DBLogger.output('executeInsert: $sql');
    return await database.rawInsert(sql);
  }

  @override
  Future<int> executeUpdate(String sql) async {
    if (_sql != null) {
      throw Exception('Redundant execution: $sql');
    }
    _sql = sql;
    DBLogger.output('executeUpdate: $sql');
    return await database.rawUpdate(sql);
  }

  @override
  Future<int> executeDelete(String sql) async {
    if (_sql != null) {
      throw Exception('Redundant execution: $sql');
    }
    _sql = sql;
    DBLogger.output('executeDelete: $sql');
    return await database.rawDelete(sql);
  }

}

class _ResultSet implements ResultSet {
  _ResultSet(this._results) : _cursor = 0;

  final List<Map<String,dynamic>> _results;
  int _cursor;

  @override
  int get row {
    if (_cursor < 0) {
      throw Exception('ResultSet closed');
    } else if (_cursor == 0 && _results.isNotEmpty) {
      throw Exception('Call next() first');
    }
    return _cursor;
  }

  @override
  bool next() {
    if (_cursor < 0) {
      throw Exception('ResultSet closed');
    // } else if (_cursor > _results.length) {
    //   throw Exception('Out of range: $_cursor, length= ${_results.length}');
    } else if (_cursor == _results.length) {
      return false;
    }
    ++_cursor;
    return true;
  }

  @override
  dynamic getValue(String columnLabel) => _results[_cursor - 1][columnLabel];

  @override
  String? getString(String column) => Converter.getString(getValue(column), null);

  @override
  bool? getBool(String column) => Converter.getBool(getValue(column), null);

  @override
  int? getInt(String column) => Converter.getInt(getValue(column), null);

  @override
  double? getDouble(String column) => Converter.getDouble(getValue(column), null);

  @override
  DateTime? getDateTime(String column) => Converter.getDateTime(getValue(column), null);

  @override
  void close() {
    _cursor = -1;
    _results.clear();
  }

}
