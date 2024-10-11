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
import 'package:mutex/mutex.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/log.dart';

import 'connector.dart';

///
///  SQLite Database Helper
///


class DatabaseHandler<T> with Logging {
  DatabaseHandler(this.connector) : _statement = null;

  final DatabaseConnector connector;

  Statement? _statement;

  void _setStatement(Statement? newSta) {
    var oldSta = _statement;
    if (oldSta == null) {
      _statement = newSta;
    } else if (identical(oldSta, newSta)) {
      // nothing changed
    } else {
      oldSta.close();
      _statement = newSta;
    }
  }

  // void destroy() {
  //   _setStatement(null);
  // }

  Future<Statement?> _connect() async {
    var conn = await connector.connection;
    if (conn == null) {
      return null;
    }
    var sta = conn.createStatement();
    _setStatement(sta);
    return sta;
  }

  ///  Query (SELECT)
  ///
  /// @param sql       - SQL
  /// @param extractor - result extractor
  /// @return rows
  /// @throws SQLException on DB error
  Future<List<T>> executeQuery(String sql, OnDataRowExtractFn<T> extractRow) async {
    Statement? sta = await _connect();
    if (sta == null) {
      logError('failed to get statement for "$sql"');
      return [];
    }
    List<T> rows = [];
    ResultSet res = await sta.executeQuery(sql);
    while (res.next()) {
      rows.add(extractRow(res, res.row - 1));
    }
    res.close();
    return rows;
  }

  ///  Update (INSERT)
  ///
  /// @param sql - SQL
  /// @return result
  /// @throws SQLException on DB error
  Future<int> executeInsert(String sql) async {
    Statement? sta = await _connect();
    if (sta == null) {
      logError('failed to get statement for "$sql"');
      return -1;
    }
    return await sta.executeInsert(sql);
  }

  ///  Update (UPDATE)
  ///
  /// @param sql - SQL
  /// @return result
  /// @throws SQLException on DB error
  Future<int> executeUpdate(String sql) async {
    Statement? sta = await _connect();
    if (sta == null) {
      logError('failed to get statement for "$sql"');
      return -1;
    }
    return await sta.executeUpdate(sql);
  }

  ///  Update (DELETE)
  ///
  /// @param sql - SQL
  /// @return result
  /// @throws SQLException on DB error
  Future<int> executeDelete(String sql) async {
    Statement? sta = await _connect();
    if (sta == null) {
      logError('failed to get statement for "$sql"');
      return -1;
    }
    return await sta.executeDelete(sql);
  }

}


abstract class DataTableHandler<T> extends DatabaseHandler<T> {
  DataTableHandler(super.connector, this.onExtract);

  final Mutex _lock = Mutex();

  // protected
  Future lock() async => await _lock.acquire();
  // protected
  unlock() => _lock.release();

  // protected
  final OnDataRowExtractFn<T> onExtract;

  /// INSERT INTO table (columns) VALUES (values);
  Future<int> insert(String table,
      {required List<String> columns, required List values}) async {
    String sql = SQLBuilder.buildInsert(table,
        columns: columns, values: values);
    return await executeInsert(sql);
  }

  /// SELECT DISTINCT columns FROM tables WHERE conditions ...
  Future<List<T>> select(String table,
      {bool distinct = false,
        required List<String> columns, required SQLConditions conditions,
        String? groupBy, String? having, String? orderBy,
        int offset = 0, int? limit}) async {
    String sql = SQLBuilder.buildSelect(table, distinct: distinct,
        columns: columns, conditions: conditions,
        groupBy: groupBy, having: having, orderBy: orderBy,
        offset: offset, limit: limit);
    return await executeQuery(sql, onExtract);
  }

  /// UPDATE table SET name=value WHERE conditions
  Future<int> update(String table,
      {required Map<String, dynamic> values,
        required SQLConditions conditions}) async {
    String sql = SQLBuilder.buildUpdate(table,
        values: values, conditions: conditions);
    return await executeUpdate(sql);
  }

  /// DELETE FROM table WHERE conditions
  Future<int> delete(String table, {required SQLConditions conditions}) async {
    String sql = SQLBuilder.buildDelete(table, conditions: conditions);
    return await executeDelete(sql);
  }

}
