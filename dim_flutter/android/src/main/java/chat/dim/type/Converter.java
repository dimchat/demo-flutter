/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
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

import java.util.Arrays;
import java.util.Date;
import java.util.List;

public interface Converter {

    static String getString(Object value, String defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof String) {
            // exactly
            return (String) value;
        } else {
            //assert false : "not a string value: " + value;
            return value.toString();
        }
    }

    /**
     *  assume value can be a config string:
     *      'true', 'false', 'yes', 'no', 'on', 'off', '1', '0', ...
     */
    static boolean getBoolean(Object value, boolean defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Boolean) {
            // exactly
            return (Boolean) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Long, Float, Double
            int num = ((Number) value).intValue();
            assert num == 1 || num == 0 : "boolean value error: " + value;
            return num != 0;
        }
        // get lower string
        String lower;
        if (value instanceof String) {
            lower = ((String) value);
        } else {
            lower = value.toString();
        }
        if (lower.isEmpty()) {
            return false;
        } else {
            lower = lower.toLowerCase();
        }
        // check false values
        if (FALSE_LIST.contains(lower)) {
            return false;
        }
        assert TRUE_LIST.contains(lower) : "boolean value error: " + value;
        return true;
    }
    List<String> FALSE_LIST = Arrays.asList(
            "0", "false", "no", "off", "null", "undefined"
    );
    List<String> TRUE_LIST = Arrays.asList(
            "1", "true", "yes", "on"
    );

    static byte getByte(Object value, byte defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Byte) {
            return (byte) value;
        } else if (value instanceof Number) {  // Short, Integer, Long, Float, Double
            return ((Number) value).byteValue();
        } else if (value instanceof Boolean) {
            return (byte) ((Boolean) value ? 1 : 0);
        }
        String str = value instanceof String ? (String) value : value.toString();
        return Byte.parseByte(str);
    }
    static short getShort(Object value, short defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Short) {
            // exactly
            return (Short) value;
        } else if (value instanceof Number) {  // Byte, Integer, Long, Float, Double
            return ((Number) value).shortValue();
        } else if (value instanceof Boolean) {
            return (short) ((Boolean) value ? 1 : 0);
        }
        String str = value instanceof String ? (String) value : value.toString();
        return Short.parseShort(str);
    }

    static int getInt(Object value, int defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Integer) {
            // exactly
            return (Integer) value;
        } else if (value instanceof Number) {  // Byte, Short, Long, Float, Double
            return ((Number) value).intValue();
        } else if (value instanceof Boolean) {
            return (Boolean) value ? 1 : 0;
        }
        String str = value instanceof String ? (String) value : value.toString();
        return Integer.parseInt(str);
    }
    static long getLong(Object value, long defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Long) {
            // exactly
            return (Long) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Float, Double
            return ((Number) value).longValue();
        } else if (value instanceof Boolean) {
            return (Boolean) value ? 1L : 0L;
        }
        String str = value instanceof String ? (String) value : value.toString();
        return Long.parseLong(str);
    }

    static float getFloat(Object value, float defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Float) {
            // exactly
            return (Float) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Long, Double
            return ((Number) value).floatValue();
        } else if (value instanceof Boolean) {
            return (Boolean) value ? 1.0F : 0.0F;
        }
        String str = value instanceof String ? (String) value : value.toString();
        return Float.parseFloat(str);
    }
    static double getDouble(Object value, double defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Double) {
            // exactly
            return (Double) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Long, Float
            return ((Number) value).doubleValue();
        } else if (value instanceof Boolean) {
            return (Boolean) value ? 1.0 : 0.0;
        }
        String str = value instanceof String ? (String) value : value.toString();
        return Double.parseDouble(str);
    }

    /**
     *  assume value can be a timestamp (seconds from 1970-01-01 00:00:00)
     */
    static Date getDateTime(Object value, Date defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Date) {
            // exactly
            return (Date) value;
        }
        double seconds = getDouble(value, 0);
        double millis = seconds * 1000;
        return new Date((long) millis);
    }

}
