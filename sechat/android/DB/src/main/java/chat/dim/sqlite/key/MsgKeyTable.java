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
package chat.dim.sqlite.key;

import android.content.ContentValues;
import android.database.Cursor;

import chat.dim.crypto.SymmetricKey;
import chat.dim.format.JSON;
import chat.dim.protocol.ID;
import chat.dim.sqlite.DataTable;
import chat.dim.sqlite.Database;

public final class MsgKeyTable extends DataTable implements chat.dim.database.MsgKeyTable {

    private MsgKeyTable() {
        super();
    }

    private static MsgKeyTable ourInstance;
    public static MsgKeyTable getInstance() {
        if (ourInstance == null) {
            ourInstance = new MsgKeyTable();
        }
        return ourInstance;
    }

    @Override
    protected Database getDatabase() {
        return KeyDatabase.getInstance();
    }

    //
    //  chat.dim.database.PrivateKeyTable
    //

    @Override
    public SymmetricKey getCipherKey(ID sender, ID receiver, boolean generate) {
        SymmetricKey key = null;
        String[] columns = {"pwd"};
        String[] selectionArgs = {sender.toString(), receiver.toString()};
        try (Cursor cursor = query(KeyDatabase.T_MESSAGE_KEY, columns,"sender=? AND receiver=?", selectionArgs, null, null,null)) {
            String sk;
            Object info;  // Map<String, Object>
            if (cursor.moveToNext()) {
                sk = cursor.getString(0);
                info = JSON.decode(sk);
                key = SymmetricKey.parse(info);
            }
        }
        return key;
    }

    @Override
    public void cacheCipherKey(ID sender, ID receiver, SymmetricKey key) {
        String[] whereArgs = {sender.toString(), receiver.toString()};
        delete(KeyDatabase.T_MESSAGE_KEY, "sender=? AND receiver=?", whereArgs);

        String text = JSON.encode(key);
        ContentValues values = new ContentValues();
        values.put("sender", sender.toString());
        values.put("receiver", receiver.toString());
        values.put("pwd", text);
        insert(KeyDatabase.T_MESSAGE_KEY, null, values);
    }
}
