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

public final class ContactTable extends DataTable implements chat.dim.database.ContactTable {

    private ContactTable() {
        super();
    }

    private static ContactTable ourInstance;
    public static ContactTable getInstance() {
        if (ourInstance == null) {
            ourInstance = new ContactTable();
        }
        return ourInstance;
    }

    @Override
    protected Database getDatabase() {
        return EntityDatabase.getInstance();
    }

    //
    //  chat.dim.database.ContactTable
    //

    @Override
    public List<ID> getLocalUsers() {
        throw new AssertionError("Call UserTable!");
    }

    @Override
    public boolean saveLocalUsers(List<ID> users) {
        throw new AssertionError("Call UserTable!");
    }

    @Override
    public List<ID> getContacts(ID user) {
        List<ID> contacts = new ArrayList<>();
        String[] columns = {"contact"};
        String[] selectionArgs = {user.toString()};
        try (Cursor cursor = query(EntityDatabase.T_CONTACT, columns, "uid=?", selectionArgs, null, null, null)) {
            ID identifier;
            while (cursor.moveToNext()) {
                identifier = ID.parse(cursor.getString(0));
                if (identifier != null) {
                    contacts.add(identifier);
                }
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return contacts;
    }

    @Override
    public boolean addContact(ID contact, ID user) {
        ContentValues values = new ContentValues();
        values.put("uid", user.toString());
        values.put("contact", contact.toString());
        return insert(EntityDatabase.T_CONTACT, null, values) >= 0;
    }

    @Override
    public boolean removeContact(ID contact, ID user) {
        String[] whereArgs = {user.toString(), contact.toString()};
        return delete(EntityDatabase.T_CONTACT, "uid=? AND contact=?", whereArgs) > 0;
    }

    @Override
    public boolean saveContacts(List<ID> newContacts, ID user) {
        int count = 0;
        // remove expelled contact(s)
        List<ID> oldContacts = getContacts(user);
        for (ID item : oldContacts) {
            if (newContacts.contains(item)) {
                continue;
            }
            if (removeContact(item, user)) {
                ++count;
            }
        }
        // insert new contact(s)
        for (ID item : newContacts) {
            if (oldContacts.contains(item)) {
                continue;
            }
            if (addContact(item, user)) {
                ++count;
            }
        }
        return count > 0;
    }
}
