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
package chat.dim.protocol;

import java.util.List;
import java.util.Map;

import chat.dim.dkd.cmd.BaseCommand;
import chat.dim.utils.ArrayUtils;

/**
 *  Command message: {
 *      type : 0x88,
 *      sn   : 123,
 *
 *      command  : "search",        // or "users"
 *      keywords : "{keywords}",    // keyword string
 *
 *      start    : 0,
 *      limit    : 20,
 *
 *      station  : "{STATION_ID}",  // station ID
 *      users    : ["{ID}"]         // user ID list
 *  }
 */
public class SearchCommand extends BaseCommand {

    public static final String SEARCH = "search";

    // search online users
    public static final String ONLINE_USERS = "users";

    public SearchCommand(Map<String, Object> content) {
        super(content);
    }

    public SearchCommand(String keywords) {
        super(ONLINE_USERS.equals(keywords) ? ONLINE_USERS : SEARCH);

        if (!ONLINE_USERS.equals(keywords)) {
            put("keywords", keywords);
        }
    }

    public String getKeywords() {
        String keywords = (String) get("keywords");
        if (keywords == null && ONLINE_USERS.equals(getCmd())) {
            keywords = ONLINE_USERS;
        }
        return keywords;
    }
    public void setKeywords(String keywords) {
        if (keywords == null) {
            remove("keywords");
        } else {
            put("keywords", keywords);
        }
    }
    public void setKeywords(List<String> keywords) {
        if (keywords == null || keywords.size() == 0) {
            remove("keywords");
        } else {
            put("keywords", ArrayUtils.join(" ", keywords));
        }
    }

    public int getStart() {
        Object start = get("start");
        return start == null ? 0 : ((Number) start).intValue();
    }
    public void setStart(int start) {
        put("start", start);
    }

    public int getLimit() {
        Object limit = get("limit");
        return limit == null ? 20 : ((Number) limit).intValue();
    }
    public void setLimit(int limit) {
        put("limit", limit);
    }

    public ID getStation() {
        return ID.parse(get("station"));
    }
    public void setStation(ID station) {
        if (station == null) {
            remove("station");
        } else {
            put("station", station.toString());
        }
    }

    /**
     *  Get user ID list
     *
     * @return ID string list
     */
    @SuppressWarnings("unchecked")
    public List<ID> getUsers() {
        List<String> users = (List) get("users");
        if (users == null) {
            return null;
        }
        return ID.convert(users);
    }
}
