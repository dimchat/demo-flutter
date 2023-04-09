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
package chat.dim.sqlite.mkm;

import android.content.ContentValues;
import android.database.Cursor;
import android.database.sqlite.SQLiteCantOpenDatabaseException;

import java.util.ArrayList;
import java.util.List;

import chat.dim.protocol.ID;
import chat.dim.sqlite.DataTable;
import chat.dim.sqlite.Database;

public final class UserTable extends DataTable implements chat.dim.database.UserTable {

    private UserTable() {
        super();
    }

    private static UserTable ourInstance;
    public static UserTable getInstance() {
        if (ourInstance == null) {
            ourInstance = new UserTable();
        }
        return ourInstance;
    }

    @Override
    protected Database getDatabase() {
        return EntityDatabase.getInstance();
    }

    private List<ID> users = null;
    private ID current = null;

    //
    //  chat.dim.database.UserTable
    //

    @Override
    public List<ID> getLocalUsers() {
        if (users != null) {
            return users;
        }
        String[] columns = {"uid"};
        try (Cursor cursor = query(EntityDatabase.T_USER, columns, null, null, null, null, "chosen DESC")) {
            users = new ArrayList<>();
            ID identifier;
            while (cursor.moveToNext()) {
                identifier = ID.parse(cursor.getString(0));
                if (identifier != null) {
                    users.add(identifier);
                }
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return users;
    }

    @Override
    public boolean saveLocalUsers(List<ID> users) {
        throw new NoSuchMethodError("implement me!");
    }

    @Override
    public List<ID> getContacts(ID user) {
        throw new AssertionError("Call ContactTable!");
    }

    @Override
    public boolean saveContacts(List<ID> contacts, ID user) {
        throw new AssertionError("Call ContactTable!");
    }

    private boolean isUserExists(ID user) {
        if (users != null) {
            return users.contains(user);
        }
        boolean exists = false;
        String[] columns = {"chosen"};
        String[] selectionArgs = {user.toString()};
        try (Cursor cursor = query(EntityDatabase.T_USER, columns, "uid=?", selectionArgs, null, null, null)) {
            if (cursor.moveToNext()) {
                // already exists
                exists = true;
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return exists;
    }

    private boolean addUser(ID user, int chosen) {
        users = null;
        if (chosen == 1) {
            current = null;
        }
        ContentValues values = new ContentValues();
        values.put("uid", user.toString());
        values.put("chosen", chosen);
        return insert(EntityDatabase.T_USER, null, values) >= 0;
    }

    @Override
    public boolean addUser(ID user) {
        if (isUserExists(user)) {
            return true;
        }
        return addUser(user, 0);
    }

    @Override
    public boolean removeUser(ID user) {
        users = null;
        current = null;
        String[] whereArgs = {user.toString()};
        return delete(EntityDatabase.T_USER, "uid=?", whereArgs) > 0;
    }

    @Override
    public void setCurrentUser(ID user) {
        ContentValues values = new ContentValues();
        values.put("chosen", 0);
        String[] whereArgs = {user.toString()};
        update(EntityDatabase.T_USER, values, "uid!=?", whereArgs);

        if (isUserExists(user)) {
            values.put("chosen", 1);
            update(EntityDatabase.T_USER, values, "uid=?", whereArgs);
            current = user;
        } else {
            addUser(user, 1);
        }
    }

    @Override
    public ID getCurrentUser() {
        if (current != null) {
            return current;
        }
        if (users != null) {
            if (users.size() == 0) {
                return null;
            }
            current = users.get(0);
            return current;
        }
        String[] columns = {"uid"};
        try (Cursor cursor = query(EntityDatabase.T_USER, columns, null, null, null, null, "chosen DESC")) {
            while (cursor.moveToNext()) {
                current = ID.parse(cursor.getString(0));
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return current;
    }
}
