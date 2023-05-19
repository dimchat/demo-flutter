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

import 'connector.dart';

///
///  SQLite Database Helper
///


class DatabaseHandler<T> {
  DatabaseHandler(this.connector) : _statement = null, _resultSet = null;

  final DatabaseConnector connector;

  Statement? _statement;
  ResultSet? _resultSet;

  void destroy() {
    Statement? st = _statement;
    if (st != null) {
      _statement = null;
      st.close();
    }
    ResultSet? res = _resultSet;
    if (res != null) {
      _resultSet = null;
      res.close();
    }
  }

  Future<DBConnection?> get connection async => connector.connection;

  Future<Statement?> get statement async {
    Statement? st = _statement;
    if (st != null) {
      // close old statement
      st.close();
      _statement = null;
    }
    // create new statement
    st = (await connection)?.createStatement();
    _statement = st;
    return st;
  }

  ///  Query (SELECT)
  ///
  /// @param sql       - SQL
  /// @param extractor - result extractor
  /// @return rows
  /// @throws SQLException on DB error
  Future<List<T>> executeQuery(String sql, OnDataRowExtractFn<T> extractRow) async {
    List<T> rows = [];
    Statement? st = await statement;
    if (st != null) {
      ResultSet res = await st.executeQuery(sql);
      _resultSet = res;
      while (res.next()) {
        rows.add(extractRow(res, res.row - 1));
      }
    }
    return rows;
  }

  ///  Update (INSERT)
  ///
  /// @param sql - SQL
  /// @return result
  /// @throws SQLException on DB error
  Future<int> executeInsert(String sql) async {
    Statement? st = await statement;
    if (st != null) {
      return await st.executeInsert(sql);
    }
    return -1;
  }

  ///  Update (UPDATE)
  ///
  /// @param sql - SQL
  /// @return result
  /// @throws SQLException on DB error
  Future<int> executeUpdate(String sql) async {
    Statement? st = await statement;
    if (st != null) {
      return await st.executeUpdate(sql);
    }
    return -1;
  }

  ///  Update (DELETE)
  ///
  /// @param sql - SQL
  /// @return result
  /// @throws SQLException on DB error
  Future<int> executeDelete(String sql) async {
    Statement? st = await statement;
    if (st != null) {
      return await st.executeDelete(sql);
    }
    return -1;
  }

}


abstract class DataTableHandler<T> extends DatabaseHandler<T> {
  DataTableHandler(super.connector, this.onExtract);

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
