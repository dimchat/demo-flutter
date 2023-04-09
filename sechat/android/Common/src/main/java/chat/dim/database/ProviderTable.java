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
package chat.dim.database;

import java.util.List;

import chat.dim.dbi.ProviderDBI;
import chat.dim.protocol.ID;

public interface ProviderTable extends ProviderDBI {

    class ProviderInfo {
        public ID identifier;
        public String name;
        public String url;
        public int chosen;

        public ProviderInfo(ID identifier, String name, String url, int chosen) {
            this.identifier = identifier;
            this.name = name;
            this.url = url;
            this.chosen = chosen;
        }
    }

    /**
     *  Get all providers
     *
     * @return provider list
     */
    List<ProviderInfo> getProviders();

    /**
     *  Add provider info
     *
     * @param identifier - sp ID
     * @param name       - sp name
     * @param url        - entrance URL
     * @param chosen     - whether current sp
     * @return false on failed
     */
    boolean addProvider(ID identifier, String name, String url, int chosen);

    /**
     *  Update provider info
     *
     * @param identifier - sp ID
     * @param name       - sp name
     * @param url        - entrance URL
     * @param chosen     - whether current sp
     * @return false on failed
     */
    boolean updateProvider(ID identifier, String name, String url, int chosen);

    /**
     *  Remove provider info
     *
     * @param identifier - sp ID
     * @return false on failed
     */
    boolean removeProvider(ID identifier);

    //
    //  Stations
    //

    class StationInfo {
        public ID identifier;
        public String name;
        public String host;
        public int port;
        public int chosen;

        public StationInfo(ID identifier, String name, String host, int port, int chosen) {
            this.identifier = identifier;
            this.name = name;
            this.host = host;
            this.port = port;
            this.chosen = chosen;
        }
    }

    /**
     *  Get all stations of this sp
     *
     * @param sp - sp ID
     * @return station list
     */
    List<StationInfo> getStations(ID sp);

    /**
     *  Add station info with sp ID
     *
     * @param sp      - sp ID
     * @param station - station ID
     * @param host    - station IP
     * @param port    - station port
     * @param name    - station name
     * @param chosen  - whether current station
     * @return false on failed
     */
    boolean addStation(ID sp, ID station, String host, int port, String name, int chosen);

    /**
     *  Update station info
     *
     * @param sp      - sp ID
     * @param station - station ID
     * @param host    - station IP
     * @param port    - station port
     * @param name    - station name
     * @param chosen  - whether current station
     * @return false on failed
     */
    boolean updateStation(ID sp, ID station, String host, int port, String name, int chosen);

    /**
     *  Set this station as current station
     *
     * @param sp      - sp ID
     * @param station - station ID
     * @return false on failed
     */
    boolean chooseStation(ID sp, ID station);

    /**
     *  Remove this station
     *
     * @param sp      - sp ID
     * @param station - station ID
     * @return false on failed
     */
    boolean removeStation(ID sp, ID station);

    /**
     *  Remove all station of the sp
     *
     * @param sp - sp ID
     * @return false on failed
     */
    boolean removeStations(ID sp);
}
