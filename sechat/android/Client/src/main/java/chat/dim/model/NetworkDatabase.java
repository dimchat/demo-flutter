/* license: https://mit-license.org
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
package chat.dim.model;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import chat.dim.database.ProviderTable;
import chat.dim.notification.NotificationCenter;
import chat.dim.notification.NotificationNames;
import chat.dim.protocol.ID;

public final class NetworkDatabase {

    private static final NetworkDatabase ourInstance = new NetworkDatabase();
    public static NetworkDatabase getInstance() { return ourInstance; }
    private NetworkDatabase() {
        super();
    }

    public ProviderTable providerTable = null;

    /**
     *  Get all service providers
     *
     * @return provider info list
     */
    public List<ProviderTable.ProviderInfo> allProviders() {
        // check providers
        List<ProviderTable.ProviderInfo> providers = providerTable.getProviders();
        if (providers != null && providers.size() > 0) {
            return providers;
        }
        providers = new ArrayList<>();
        providers.add(defaultProviderInfo());
        return providers;
    }

    /**
     *  Save provider
     *
     * @param identifier - provider ID
     * @param name - provider name
     * @param url - config URL
     * @return true on success
     */
    public boolean addProvider(ID identifier, String name, String url, int chosen) {
        return providerTable.addProvider(identifier, name, url, chosen);
    }

    //-------- Station

    /**
     *  Get all stations under the service provider
     *
     * @param sp - sp ID
     * @return station info list
     */
    public List<ProviderTable.StationInfo> allStations(ID sp) {
        return providerTable.getStations(sp);
    }

    /**
     *  Save station info for the service provider
     *
     * @param sp - sp ID
     * @param station - station ID
     * @param host - station host
     * @param port - station port
     * @param name - station name
     * @return true on success
     */
    public boolean addStation(ID sp, ID station, String host, int port, String name, int chosen) {
        if (!providerTable.addStation(sp, station, host, port, name, chosen)) {
            return false;
        }
        Map<String, Object> userInfo = new HashMap<>();
        userInfo.put("sp", sp);
        userInfo.put("action", "add");
        userInfo.put("station", station);
        userInfo.put("chosen", chosen);
        NotificationCenter nc = NotificationCenter.getInstance();
        nc.postNotification(NotificationNames.ServiceProviderUpdated, this, userInfo);
        return true;
    }

    public boolean chooseStation(ID sp, ID station) {
        if (!providerTable.chooseStation(sp, station)) {
            return false;
        }
        Map<String, Object> userInfo = new HashMap<>();
        userInfo.put("sp", sp);
        userInfo.put("action", "switch");
        userInfo.put("station", station);
        userInfo.put("chosen", 1);
        NotificationCenter nc = NotificationCenter.getInstance();
        nc.postNotification(NotificationNames.ServiceProviderUpdated, this, userInfo);
        return true;
    }
    public boolean removeStation(ID sp, ID station, String host, int port) {
        if (!providerTable.removeStation(sp, station)) {
            return false;
        }
        Map<String, Object> userInfo = new HashMap<>();
        userInfo.put("sp", sp);
        userInfo.put("action", "remove");
        userInfo.put("station", station);
        userInfo.put("host", host);
        userInfo.put("port", port);
        NotificationCenter nc = NotificationCenter.getInstance();
        nc.postNotification(NotificationNames.ServiceProviderUpdated, this, userInfo);
        return true;
    }

    @SuppressWarnings("unchecked")
    private ProviderTable.ProviderInfo defaultProviderInfo() {

        Map<String, Object> spConfig = Configuration.getInstance().getDefaultProvider();

        ID sp = ID.parse(spConfig.get("ID"));
        String name = (String) spConfig.get("name");
        String url = (String) spConfig.get("URL");
        addProvider(sp, name, url, 1);

        List<Map> stations = (List<Map>) spConfig.get("stations");
        ID sid;
        String host;
        int port;

        int chosen = 1;

        for (Map item : stations) {
            sid = ID.parse(item.get("ID"));
            host = (String) item.get("host");
            port = (int) item.get("port");
            name = (String) item.get("name");
            addStation(sp, sid, host, port, name, chosen);
            chosen = 0;
        }

        return new ProviderTable.ProviderInfo(sp, name, url, 1);
    }
}
