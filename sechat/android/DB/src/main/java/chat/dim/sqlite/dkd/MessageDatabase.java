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
package chat.dim.sqlite.dkd;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;

import java.util.HashMap;
import java.util.Map;

import chat.dim.Messenger;
import chat.dim.format.JSON;
import chat.dim.protocol.InstantMessage;
import chat.dim.sqlite.Database;

public final class MessageDatabase extends Database {

    private MessageDatabase(Context context, String name, int version) {
        super(context, name, version);
    }

    public static Messenger messenger = null;

    private static MessageDatabase ourInstance = null;

    static MessageDatabase getInstance() {
        if (ourInstance == null) {
            ourInstance = new MessageDatabase(context, DB_NAME, DB_VERSION);
        }
        return ourInstance;
    }

    private static final String DB_NAME = "dkd.db";
    private static final int DB_VERSION = 1;

    static final String T_MESSAGE = "t_message";
    static final String T_TRACE = "t_trace";

    //
    //  SQLiteOpenHelper
    //

    @Override
    public void onCreate(SQLiteDatabase db) {
        // messages
        db.execSQL("CREATE TABLE " + T_MESSAGE + "(cid VARCHAR(64), sender VARCHAR(64), receiver VARCHAR(64), time INTEGER," +
                // content info
                " content TEXT, type INTEGER, sn VARCHAR(20)," +
                // extra info
                " signature VARCHAR(8), read BIT)");
        db.execSQL("CREATE INDEX cid_index ON " + T_MESSAGE + "(cid)");

        // traces for messages
        db.execSQL("CREATE TABLE " + T_TRACE + "(cid VARCHAR(64), sn VARCHAR(20), signature VARCHAR(8), trace TEXT)");
        db.execSQL("CREATE INDEX trace_id_index ON " + T_TRACE + "(cid)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
    }

    //
    //  DaoKeDao
    //

    @SuppressWarnings("unchecked")
    static InstantMessage getInstanceMessage(String sender, String receiver, long timestamp, String content) {
        Object dict = JSON.decode(content);
        if (dict == null) {
            throw new NullPointerException("message content error: " + content);
        }
        // FIXME: fix a typo: 'tine' => 'time' in message content
        fixTine((Map<String, Object>) dict);
        Map<String, Object> msg = new HashMap<>();
        msg.put("sender", sender);
        msg.put("receiver", receiver);
        msg.put("time", timestamp);
        msg.put("content", dict);
        return getInstanceMessage(msg);
    }
    private static void fixTine(Map<String, Object> info) {
        // copy 'time' from 'tine'
        Object time = info.get("time");
        if (time == null) {
            Object tine = info.get("tine");
            if (tine != null) {
                info.put("time", tine);
            }
        }
    }

    @SuppressWarnings("rawtypes")
    private static InstantMessage getInstanceMessage(Map msg) {
        InstantMessage iMsg = InstantMessage.parse(msg);
        if (iMsg != null) {
            iMsg.setDelegate(messenger);
        }
        return iMsg;
    }
}
