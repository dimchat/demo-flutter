/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2020 Albert Moky
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
 * ==============================================================================
 */
package chat.dim.sqlite.ans;

import android.content.ContentValues;
import android.database.Cursor;
import android.database.sqlite.SQLiteCantOpenDatabaseException;

import chat.dim.protocol.ID;
import chat.dim.sqlite.DataTable;
import chat.dim.sqlite.Database;

public final class AddressNameTable extends DataTable implements chat.dim.database.AddressNameTable {

    private AddressNameTable() {
        super();
    }

    private static AddressNameTable ourInstance;
    public static AddressNameTable getInstance() {
        if (ourInstance == null) {
            ourInstance = new AddressNameTable();
        }
        return ourInstance;
    }

    @Override
    protected Database getDatabase() {
        return AddressNameDatabase.getInstance();
    }

    //
    //  chat.dim.database.AddressNameTable
    //

    @Override
    public ID getIdentifier(String alias) {
        ID identifier = null;
        String[] columns = {"did"};
        String[] selectionArgs = {alias};
        try (Cursor cursor = query(AddressNameDatabase.T_RECORD, columns, "alias=?", selectionArgs, null, null, null)) {
            if (cursor.moveToNext()) {
                identifier = ID.parse(cursor.getString(0));
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return identifier;
    }

    @Override
    public boolean addRecord(ID identifier, String alias) {
        ContentValues values = new ContentValues();
        values.put("did", identifier.toString());
        if (getIdentifier(alias) == null) {
            // not exists, add new record
            values.put("alias", alias);
            return insert(AddressNameDatabase.T_RECORD, null, values) >= 0;
        } else {
            // update record
            String[] whereArgs = {alias};
            return update(AddressNameDatabase.T_RECORD, values, "alias=?", whereArgs) > 0;
        }
    }

    @Override
    public boolean removeRecord(String alias) {
        String[] whereArgs = {alias};
        return delete(AddressNameDatabase.T_RECORD, "alias=?", whereArgs) > 0;
    }
}
