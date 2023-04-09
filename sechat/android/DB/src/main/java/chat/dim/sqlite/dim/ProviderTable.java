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

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import chat.dim.protocol.ID;
import chat.dim.sqlite.DataTable;
import chat.dim.sqlite.Database;
import chat.dim.type.Triplet;

public final class ProviderTable extends DataTable implements chat.dim.database.ProviderTable {

    private ProviderTable() {
        super();
    }

    private static ProviderTable ourInstance;
    public static ProviderTable getInstance() {
        if (ourInstance == null) {
            ourInstance = new ProviderTable();
        }
        return ourInstance;
    }

    @Override
    protected Database getDatabase() {
        return MainDatabase.getInstance();
    }

    //
    //  chat.dim.database.ProviderTable
    //

    @Override
    public List<ProviderInfo> getProviders() {
        List<ProviderInfo> providers = new ArrayList<>();
        String[] columns = {"spid", "name", "url", "chosen"};
        try (Cursor cursor = query(MainDatabase.T_PROVIDER, columns, null, null, null, null, "chosen DESC")) {
            ID identifier;
            String name;
            String url;
            int chosen;
            while (cursor.moveToNext()) {
                identifier = ID.parse(cursor.getString(0));
                name = cursor.getString(1);
                url = cursor.getString(2);
                chosen = cursor.getInt(3);
                providers.add(new ProviderInfo(identifier, name, url, chosen));
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return providers;
    }

    @Override
    public boolean addProvider(ID identifier, String name, String url, int chosen) {
        ContentValues values = new ContentValues();
        values.put("spid", identifier.toString());
        values.put("name", name);
        values.put("url", url);
        values.put("chosen", chosen);
        return insert(MainDatabase.T_PROVIDER, null, values) >= 0;
    }

    @Override
    public boolean updateProvider(ID identifier, String name, String url, int chosen) {
        ContentValues values = new ContentValues();
        values.put("name", name);
        values.put("url", url);
        values.put("chosen", chosen);
        String[] whereArgs = {identifier.toString()};
        return update(MainDatabase.T_PROVIDER, values, "spid=?", whereArgs) > 0;
    }

    @Override
    public boolean removeProvider(ID identifier) {
        String[] whereArgs = {identifier.toString()};
        return delete(MainDatabase.T_PROVIDER, "spid=?", whereArgs) > 0;
    }

    @Override
    public List<StationInfo> getStations(ID sp) {
        List<StationInfo> stations = new ArrayList<>();
        String[] columns = {"sid", "name", "host", "port", "chosen"};
        String[] selectionArgs = {sp.toString()};
        try (Cursor cursor = query(MainDatabase.T_STATION, columns, "spid=?", selectionArgs, null, null, "chosen DESC")) {
            ID identifier;
            String name;
            String host;
            int port;
            int chosen;
            while (cursor.moveToNext()) {
                identifier = ID.parse(cursor.getString(0));
                name = cursor.getString(1);
                host = cursor.getString(2);
                port = cursor.getInt(3);
                chosen = cursor.getInt(4);
                stations.add(new StationInfo(identifier, name, host, port, chosen));
            }
        } catch (SQLiteCantOpenDatabaseException e) {
            e.printStackTrace();
        }
        return stations;
    }

    @Override
    public boolean addStation(ID sp, ID station, String host, int port, String name, int chosen) {
        ContentValues values = new ContentValues();
        values.put("spid", sp.toString());
        values.put("sid", station.toString());
        values.put("name", name);
        values.put("host", host);
        values.put("port", port);
        values.put("chosen", chosen);
        return insert(MainDatabase.T_STATION, null, values) >= 0;
    }

    @Override
    public boolean updateStation(ID sp, ID station, String host, int port, String name, int chosen) {
        ContentValues values = new ContentValues();
        values.put("name", name);
        values.put("host", host);
        values.put("port", port);
        values.put("chosen", chosen);
        String[] whereArgs = {sp.toString(), station.toString()};
        return update(MainDatabase.T_STATION, values, "spid=? AND sid=?", whereArgs) > 0;
    }

    @Override
    public boolean chooseStation(ID sp, ID station) {
        ContentValues values = new ContentValues();
        values.put("chosen", 0);
        String[] whereArgs1 = {sp.toString()};
        update(MainDatabase.T_STATION, values, "spid=? AND chosen=1", whereArgs1);

        values.put("chosen", 1);
        String[] whereArgs2 = {sp.toString(), station.toString()};
        return update(MainDatabase.T_STATION, values, "spid=? AND sid=?", whereArgs2) > 0;
    }

    @Override
    public boolean removeStation(ID sp, ID station) {
        String[] whereArgs = {sp.toString(), station.toString()};
        return delete(MainDatabase.T_STATION, "spid=? AND sid=?", whereArgs) > 0;
    }

    @Override
    public boolean removeStations(ID sp) {
        String[] whereArgs = {sp.toString()};
        return delete(MainDatabase.T_STATION, "spid=?", whereArgs) > 0;
    }

    //
    //  Provider DBI
    //

    @Override
    public Set<Triplet<String, Integer, ID>> allNeighbors() {
        return null;
    }

    @Override
    public ID getNeighbor(String ip, int port) {
        return null;
    }

    @Override
    public boolean addNeighbor(String ip, int port, ID station) {
        return false;
    }

    @Override
    public boolean removeNeighbor(String ip, int port) {
        return false;
    }
}
