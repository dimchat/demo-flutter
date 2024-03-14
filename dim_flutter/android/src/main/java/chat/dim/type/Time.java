/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2022 Albert Moky
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
package chat.dim.type;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public final class Time extends Date {

    public Time() {
        super();
    }
    public Time(long mills) {
        super(mills);
    }

    public static float getTimestamp(Date date) {
        return date.getTime() / 1000.0f;
    }

    //
    //  Factory methods
    //

    public static Time parseTime(Object time) {
        if (time == null) {
            return null;
        } else if (time instanceof Time) {
            return (Time) time;
        }
        Date date = Converter.getDateTime(time, null);
        //assert date != null : "should not happen";
        return new Time(date.getTime());
    }

    public static Date now() {
        return new Date();
    }

    /**
     *  Fuzzy comparing times
     *
     * @param time1 - date 1
     * @param time2 - date 2
     * @return -1 on time1 before than time2, 1 on time1 after than time2
     */
    public static int fuzzyCompare(Date time1, Date time2) {
        long t1 = time1.getTime();
        long t2 = time2.getTime();
        if (t1 < (t2 - 60 * 1000)) {
            return -1;
        }
        if (t1 > (t2 + 60 * 1000)) {
            return 1;
        }
        return 0;
    }

    /**
     *  Get readable time string
     *
     * @param date - time
     * @return readable string
     */
    public static String getTimeString(Date date) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTime(now());
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        long midnight = calendar.getTimeInMillis();

        long timestamp = date.getTime();
        if (timestamp >= midnight) {
            // today
            return getTimeString(date, "a HH:mm");
        } else if (timestamp >= (midnight - 72 * 3600 * 1000)) {
            // recently
            return getTimeString(date, "EEEE HH:mm");
        }
        calendar.set(Calendar.MONTH, 0);
        calendar.set(Calendar.DAY_OF_MONTH, 0);
        long begin = calendar.getTimeInMillis();
        if (timestamp >= begin) {
            // this year
            return getTimeString(date, "MM-dd HH:mm");
        } else {
            return getTimeString(date, "yyyy-MM-dd HH:mm");
        }
    }
    public static String getTimeString(Date date, String pattern) {
        SimpleDateFormat formatter = new SimpleDateFormat(pattern, Locale.CHINA);
        return formatter.format(date);
    }

    public static String getFullTimeString(long date) {
        return getTimeString(new Date(date), "yyyy-MM-dd HH:mm:ss");
    }
    public static String getFullTimeString(Date date) {
        return getTimeString(date, "yyyy-MM-dd HH:mm:ss");
    }
}
