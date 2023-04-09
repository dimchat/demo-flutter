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

import java.util.HashMap;
import java.util.Map;

import chat.dim.format.Base64;
import chat.dim.mkm.BaseDocument;
import chat.dim.protocol.Document;
import chat.dim.protocol.ID;
import chat.dim.sqlite.DataTable;
import chat.dim.sqlite.Database;
import chat.dim.utils.Log;

public final class DocumentTable extends DataTable implements chat.dim.database.DocumentTable {

    private DocumentTable() {
        super();
    }

    private static DocumentTable ourInstance;
    public static DocumentTable getInstance() {
        if (ourInstance == null) {
            ourInstance = new DocumentTable();
        }
        return ourInstance;
    }

    @Override
    protected Database getDatabase() {
        return EntityDatabase.getInstance();
    }

    // memory caches
    private Map<String, Document> docsTable = new HashMap<>();

    private final Document empty = new BaseDocument(ID.ANYONE, Document.PROFILE);

    //
    //  chat.dim.database.UserTable
    //

    // TODO: support multi documents
    @Override
    public boolean saveDocument(Document doc) {
        if (!doc.isValid()) {
            Log.error("document not valid: " + doc);
            return false;
        }
        ID identifier = doc.getIdentifier();

        // 0. check duplicate record
        Document old = getDocument(identifier, doc.getType());
        if (old != null) {
            Log.info("entity document exists, update it: " + identifier);
            String[] whereArgs = {identifier.toString()};
            delete(EntityDatabase.T_PROFILE, "did=?", whereArgs);
        }
        String data = (String) doc.get("data");
        String base64 = (String) doc.get("signature");

        // 1. save into database
        ContentValues values = new ContentValues();
        values.put("did", identifier.toString());
        values.put("data", data);
        values.put("signature", Base64.decode(base64));
        if (insert(EntityDatabase.T_PROFILE, null, values) < 0) {
            return false;
        }
        Log.info("-------- entity document updated: " + identifier);

        // 2. store into memory cache
        docsTable.put(identifier.toString(), doc);
        return true;
    }

    @Override
    public Document getDocument(ID entity, String type) {
        if (type == null || type.length() == 0) {
            type = "*";
        }
        // 1. try from memory cache
        Document doc = docsTable.get(entity.toString());
        if (doc == null) {
            // 2. try from database
            String[] columns = {"data", "signature"};
            String[] selectionArgs = {entity.toString()};
            try (Cursor cursor = query(EntityDatabase.T_PROFILE, columns, "did=?", selectionArgs, null, null, null)) {
                String data;
                byte[] signature;
                if (cursor.moveToNext()) {
                    data = cursor.getString(0);
                    signature = cursor.getBlob(1);
                    doc = Document.create(type, entity, data, Base64.encode(signature));
                }
            } catch (SQLiteCantOpenDatabaseException e) {
                e.printStackTrace();
            }
            if (doc == null) {
                // 2.1. place an empty document for cache
                doc = empty;
            }

            // 3. store into memory cache
            docsTable.put(entity.toString(), doc);
        }
        if (doc == empty) {
            return null;
        }
        if (type.equals("*")) {
            if (entity.isGroup()) {
                type = Document.BULLETIN;
            } else {
                type = Document.VISA;
            }
        }
        doc.put("type", type);
        return doc;
    }
}
