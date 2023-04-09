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

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;

import chat.dim.sqlite.Database;

public final class MainDatabase extends Database {

    private MainDatabase(Context context, String name, int version) {
        super(context, name, version);
    }

    private static MainDatabase ourInstance = null;

    static MainDatabase getInstance() {
        if (ourInstance == null) {
            ourInstance = new MainDatabase(context, DB_NAME, DB_VERSION);
        }
        return ourInstance;
    }

    private static final String DB_NAME = "dim.db";
    private static final int DB_VERSION = 1;

    static final String T_PROVIDER = "t_provider";
    static final String T_STATION = "t_station";

    static final String T_LOGIN = "t_login";

    //
    //  SQLiteOpenHelper
    //

    @Override
    public void onCreate(SQLiteDatabase db) {
        // service providers
        db.execSQL("CREATE TABLE " + T_PROVIDER + "(spid VARCHAR(64), name VARCHAR(32), url VARCHAR(128), chosen BIT)");

        // stations
        db.execSQL("CREATE TABLE " + T_STATION + "(sid VARCHAR(64), spid VARCHAR(64), name VARCHAR(32), host VARCHAR(32), port INTEGER, chosen BIT)");

        // login info
        db.execSQL("CREATE TABLE " + T_LOGIN + "(uid VARCHAR(64), time INTEGER, station VARCHAR(64), command TEXT)");
        db.execSQL("CREATE INDEX user_id_index ON " + T_LOGIN + "(uid)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
    }
}
