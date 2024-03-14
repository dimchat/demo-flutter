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
package chat.dim.utils;

import java.util.Arrays;
import java.util.Date;

import chat.dim.type.Time;

public final class Log {

    public static final int DEBUG_FLAG = 0x01;
    public static final int INFO_FLAG = 0x02;
    public static final int WARNING_FLAG = 0x04;
    public static final int ERROR_FLAG = 0x08;

    public static final int DEBUG = DEBUG_FLAG | INFO_FLAG | WARNING_FLAG | ERROR_FLAG;
    public static final int DEVELOP = INFO_FLAG | WARNING_FLAG | ERROR_FLAG;
    public static final int RELEASE = WARNING_FLAG | ERROR_FLAG;

    public static int LEVEL = RELEASE;

    public static String getTime() {
        Date now = Time.now();
        return Time.getFullTimeString(now);
    }

    private static String getLocation() {
        String filename = null;
        int line = -1;
        StackTraceElement[] traces = Thread.currentThread().getStackTrace();
        boolean flag = false;
        for (StackTraceElement element : traces) {
            filename = element.getFileName();
            if (filename != null && filename.endsWith("Log.java")) {
                flag = true;
            } else if (flag) {
                line = element.getLineNumber();
                break;
            }
        }
        assert filename != null && line >= 0 : "traces error: " + Arrays.toString(traces);
        filename = filename.split("\\.")[0];
        return filename + ":" + line;
    }

    public static void debug(String msg) {
        if ((LEVEL & DEBUG_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        System.out.println("[" + time + "] DEBUG - " + loc + " >\t" + msg);
    }

    public static void info(String msg) {
        if ((LEVEL & INFO_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        System.out.println("[" + time + "] " + loc + " >\t" + msg);
    }

    public static void warning(String msg) {
        if ((LEVEL & WARNING_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        System.out.println("[" + time + "] WARNING - " + loc + " >\t" + msg);
    }

    public static void error(String msg) {
        if ((LEVEL & ERROR_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        System.out.println("[" + time + "] ERROR - " + loc + " >\t" + msg);
    }
}
