/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                                Written in 2019 by Moky <albert.moky@gmail.com>
 *
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2019 Albert Moky
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
package chat.dim.http;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

import chat.dim.utils.Log;

public enum VersionManager {

    INSTANCE;

    public static VersionManager getInstance() {
        return INSTANCE;
    }

    // "https://raw.githubusercontent.com/dimchat/demo-flutter/main/sechat/assets/apk-release.json";
    static final String ENTRANCE = "http://tarsier.dim.chat/v1/apk-release.json";

    private JSONObject newestInfo = null;

    private JSONObject download() {
        try {
            URL url = new URL(ENTRANCE);
            Log.info("trying to download config: " + url);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setConnectTimeout(5000);
            connection.setRequestMethod("GET");
            InputStream is = connection.getInputStream();
            BufferedReader reader = new BufferedReader(new InputStreamReader(is));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            Log.info("config downloaded: " + url);
            newestInfo = getNewestItem(new JSONObject(response.toString()));
        } catch (Exception e) {
            e.printStackTrace();
            Log.error("failed to download config: " + ENTRANCE);
        } catch (Error e) {
            e.printStackTrace();
            Log.error("failed to download config: " + ENTRANCE);
        }
        return newestInfo;
    }
    private static JSONObject getNewestItem(JSONObject jsonObject) throws JSONException {
        if (jsonObject.isNull("newest")) {
            JSONArray array = jsonObject.getJSONArray("elements");
            return array.length() > 0 ? array.getJSONObject(0) : new JSONObject();
        } else {
            return jsonObject.getJSONObject("newest");
        }
    }

    public JSONObject downloadNewestInfo() {
        JSONObject info = newestInfo;
        if (info == null) {
            info = download();
            Log.info("downloaded newest info: " + ENTRANCE + ", " + info);
        }
        return info;
    }

    public String getNewestApk() {
        JSONObject info = newestInfo;
        if (info == null) {
            return null;
        }
        try {
            if (info.isNull("url")) {
                String filename = info.getString("outputFile");
                String base = ENTRANCE.substring(0, ENTRANCE.lastIndexOf("/") + 1);
                Log.warning("get apk url: " + base + filename);
                return base + filename;
            }
            return info.getString("url");
        } catch (Exception e) {
            e.printStackTrace();
            Log.error("failed to get apk url: " + info);
            return null;
        }
    }

    public String getNewestVersionName() {
        JSONObject info = newestInfo;
        if (info == null) {
            return null;
        }
        try {
            return info.getString("versionName");
        } catch (Exception e) {
            e.printStackTrace();
            Log.error("failed to get apk version: " + info);
            return null;
        }
    }

    public int getNewestVersionCode() {
        JSONObject info = newestInfo;
        if (info == null) {
            return 0;
        }
        try {
            return info.getInt("versionCode");
        } catch (Exception e) {
            e.printStackTrace();
            Log.error("failed to get version code: " + info);
            return -1;
        }
    }

    private static int getCurrentVersionCode(Context context) {
        try {
            PackageManager packageManager = context.getPackageManager();
            String name = context.getPackageName();
            PackageInfo packageInfo = packageManager.getPackageInfo(name, 0);
            return packageInfo.versionCode;
        } catch (Exception e) {
            e.printStackTrace();
            Log.error("failed to get current version code");
            return -1;
        }
    }

    public boolean isNewest(Context context) {
        int current = getCurrentVersionCode(context);
        int newest = getNewestVersionCode();
        if (current <= 0 || newest <= 0) {
            Log.error("failed to get versions: " + current + ", newest: " + newest);
            return true;
        }
        Log.info("checking versions: " + current + ", newest: " + newest);
        return current >= newest;
    }

}
