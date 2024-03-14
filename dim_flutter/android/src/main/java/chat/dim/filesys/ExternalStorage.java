/* license: https://mit-license.org
 *
 *  File System
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
package chat.dim.filesys;

import java.io.File;
import java.io.IOException;

import chat.dim.format.JSON;
import chat.dim.format.UTF8;

/**
 *  RAM access
 */
public abstract class ExternalStorage {

    /**
     *  Forbid the gallery from scanning media files
     *
     * @param dir - data directory
     * @return true on success
     */
    public static boolean setNoMedia(String dir) {
        try {
            String path = Paths.append(dir, ".nomedia");
            if (!Paths.exists(path)) {
                Storage file = new Storage();
                file.setData(UTF8.encode("Moky loves May Lee forever!"));
                file.write(path);
            }
            return true;
        } catch (IOException e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     *  Delete expired files in this directory cyclically
     *
     * @param dir     - directory
     * @param expired - expired time (milliseconds, from Jan 1, 1970 UTC)
     */
    public static void cleanup(String dir, long expired) {
        File file = new File(dir);
        if (file.exists()) {
            cleanupFile(file, expired);
        }
    }

    @SuppressWarnings("ResultOfMethodCallIgnored")
    private static void cleanupFile(File file, long expired) {
        if (file.isDirectory()) {
            cleanupDirectory(file, expired);
        } else if (file.lastModified() < expired) {
            file.delete();
        }
    }
    private static void cleanupDirectory(File dir, long expired) {
        File[] children = dir.listFiles();
        if (children == null || children.length == 0) {
            // directory empty
            return;
        }
        for (File child : children) {
            cleanupFile(child, expired);
        }
    }

    //-------- read

    private static byte[] load(String path) throws IOException {
        Storage file = new Storage();
        file.read(path);
        return file.getData();
    }

    /**
     *  Load binary data from file
     *
     * @param path - file path
     * @return file data
     */
    public static byte[] loadBinary(String path) throws IOException {
        byte[] data = load(path);
        if (data == null) {
            throw new IOException("failed to load binary file: " + path);
        }
        return data;
    }

    /**
     *  Load text from file path
     *
     * @param path - file path
     * @return text string
     */
    public static String loadText(String path) throws IOException {
        byte[] data = load(path);
        if (data == null) {
            throw new IOException("failed to load text file: " + path);
        }
        return UTF8.decode(data);
    }

    /**
     *  Load JSON from file path
     *
     * @param path - file path
     * @return Map/List object
     */
    public static Object loadJSON(String path) throws IOException {
        byte[] data = load(path);
        if (data == null) {
            throw new IOException("failed to load JSON file: " + path);
        }
        return JSON.decode(UTF8.decode(data));
    }

    //-------- write

    private static int save(byte[] data, String path) throws IOException {
        Storage file = new Storage();
        file.setData(data);
        return file.write(path);
    }

    /**
     *  Save data into binary file
     *
     * @param data - binary data
     * @param path - file path
     * @return true on success
     */
    public static int saveBinary(byte[] data, String path) throws IOException {
        int len = save(data, path);
        if (len != data.length) {
            throw new IOException("failed to save binary file: " + path);
        }
        return len;
    }

    /**
     *  Save string into Text file
     *
     * @param text - text string
     * @param path - file path
     * @return true on success
     */
    public static int saveText(String text, String path) throws IOException {
        byte[] data = UTF8.encode(text);
        int len = save(data, path);
        if (len != data.length) {
            throw new IOException("failed to save text file: " + path);
        }
        return len;
    }

    /**
     *  Save Map/List into JSON file
     *
     * @param object - Map/List object
     * @param path - file path
     * @return true on success
     */
    public static int saveJSON(Object object, String path) throws IOException {
        byte[] json = UTF8.encode(JSON.encode(object));
        int len = save(json, path);
        if (len != json.length) {
            throw new IOException("failed to save text file: " + path);
        }
        return len;
    }
}
