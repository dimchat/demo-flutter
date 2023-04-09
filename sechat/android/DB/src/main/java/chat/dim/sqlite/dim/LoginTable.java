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
package chat.dim.sqlite.dim;

import android.content.ContentValues;
import android.database.Cursor;
import android.database.sqlite.SQLiteCantOpenDatabaseException;

import java.util.Date;
import java.util.Map;

import chat.dim.format.JSON;
import chat.dim.protocol.ID;
import chat.dim.protocol.LoginCommand;
import chat.dim.protocol.ReliableMessage;
import chat.dim.sqlite.DataTable;
import chat.dim.sqlite.Database;
import chat.dim.type.Pair;

public final class LoginTable extends DataTable implements chat.dim.database.LoginTable {

    private LoginTable() {
        super();
    }

    private static LoginTable ourInstance;
    public static LoginTable getInstance() {
        if (ourInstance == null) {
            ourInstance = new LoginTable();
        }
        return ourInstance;
    }

    @Override
    protected Database getDatabase() {
        return MainDatabase.getInstance();
    }

    //
    //  access for "LOGIN" command
    //

    @SuppressWarnings("unchecked")
    @Override
    public LoginCommand getLoginCommand(ID user) {
        String[] columns = {"command"};
        String[] selectionArgs = {user.toString()};
        try (Cursor cursor = query(MainDatabase.T_LOGIN, columns, "uid=?", selectionArgs, null, null, null)) {
            String text;
            Object info;
            if (cursor.moveToNext()) {
                text = cursor.getString(0);
                info = JSON.decode(text);
                if (info instanceof Map) {
                    // FIXME: fix a typo: 'tine' => 'time' in message content
                    fixTine((Map<String, Object>) info);
                    return new LoginCommand((Map<String, Object>) info);
                }
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return null;
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

    @Override
    public boolean saveLoginCommand(LoginCommand command) {
        ID user = command.getIdentifier();
        Date oldTime = getLoginTime(user);
        Map<String, Object> station = command.getStation();
        String sid = (String) station.get("ID");
        String text = JSON.encode(command);

        ContentValues values = new ContentValues();
        values.put("station", sid);
        values.put("command", text);
        if (oldTime == null) {
            // not exists, insert new record
            values.put("uid", user.toString());
            Date time = command.getTime();
            if (time != null) {
                values.put("time", time.getTime() / 1000);
            }
            return insert(MainDatabase.T_LOGIN, null, values) >= 0;
        } else {
            // update record with user ID
            if (oldTime.after(command.getTime())) {
                values.put("time", oldTime.getTime() / 1000);
            } else {
                Date time = command.getTime();
                if (time != null) {
                    values.put("time", time.getTime() / 1000);
                }
            }
            String[] whereArgs = {user.toString()};
            return update(MainDatabase.T_LOGIN, values, "uid=?", whereArgs) > 0;
        }
    }

    private Date getLoginTime(ID user) {
        String[] columns = {"time"};
        String[] selectionArgs = {user.toString()};
        try (Cursor cursor = query(MainDatabase.T_LOGIN, columns, "uid=?", selectionArgs, null, null, null)) {
            long time;
            if (cursor.moveToNext()) {
                time = cursor.getLong(0);
                return new Date(time * 1000);
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return null;
    }

    public boolean update(ID user, Date time) {
        Date oldTime = getLoginTime(user);

        ContentValues values = new ContentValues();
        values.put("time", time.getTime() / 1000);
        if (oldTime == null) {
            // not exists, insert new record
            values.put("uid", user.toString());
            return insert(MainDatabase.T_LOGIN, null, values) >= 0;
        } else if (oldTime.after(time)) {
            // error
            return false;
        } else {
            String[] whereArgs = {user.toString()};
            return update(MainDatabase.T_LOGIN, values, "uid=?", whereArgs) > 0;
        }
    }

    @Override
    public Pair<LoginCommand, ReliableMessage> getLoginCommandMessage(ID identifier) {
        LoginCommand content = getLoginCommand(identifier);
        return new Pair<>(content, null);
    }

    @Override
    public boolean saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg) {
        return saveLoginCommand(content);
    }
}
