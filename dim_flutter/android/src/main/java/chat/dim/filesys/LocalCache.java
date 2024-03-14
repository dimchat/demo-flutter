/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                                Written in 2022 by Moky <albert.moky@gmail.com>
 *
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
package chat.dim.filesys;

public enum LocalCache {

    INSTANCE;

    public static LocalCache getInstance() {
        return INSTANCE;
    }

    //
    //  Directories
    //
    private String cacheDir = "/tmp/.dim";
    private String tmpDir = "/tmp/.dim";
    private boolean cacheBuilt = false;
    private boolean tmpBuilt = false;

    private boolean buildDir(String root, boolean built) {
        if (built) {
            return true;
        }
        // make sure base directory built, and
        // forbid the gallery from scanning media files
        return Paths.mkdirs(root) && ExternalStorage.setNoMedia(root);
    }

    /**
     *  Protected caches directory
     *  (meta/visa/document, image/audio/video, ...)
     *
     * @return "/sdcard/Android/data/chat.dim.sechat/cache"
     */
    public String getCachesDirectory() {
        cacheBuilt = buildDir(cacheDir, cacheBuilt);
        return cacheDir;
    }
    public void setCachesDirectory(String root) {
        cacheDir = root;
        cacheBuilt = false;
    }

    /**
     *  Protected temporary directory
     *  (uploading, downloaded)
     *
     * @return "/data/data/chat.dim.sechat/cache"
     */
    public String getTemporaryDirectory() {
        tmpBuilt = buildDir(tmpDir, tmpBuilt);
        return tmpDir;
    }
    public void setTemporaryDirectory(String root) {
        tmpDir = root;
        tmpBuilt = false;
    }

    //
    //  Paths
    //

    /**
     *  Avatar image file path
     *
     * @param filename - image filename: hex(md5(data)) + ext
     * @return "/sdcard/chat.dim.sechat/caches/avatar/{AA}/{BB}/{filename}"
     */
    public String getAvatarFilePath(String filename) {
        String dir = getCachesDirectory();
        String AA = filename.substring(0, 2);
        String BB = filename.substring(2, 4);
        return Paths.append(dir, "avatar", AA, BB, filename);
    }

    /**
     *  Cached file path
     *  (image, audio, video, ...)
     *
     * @param filename - messaged filename: hex(md5(data)) + ext
     * @return "/sdcard/chat.dim.sechat/caches/files/{AA}/{BB}/{filename}"
     */
    public String getCacheFilePath(String filename) {
        String dir = getCachesDirectory();
        String AA = filename.substring(0, 2);
        String BB = filename.substring(2, 4);
        return Paths.append(dir, "files", AA, BB, filename);
    }

    /**
     *  Encrypted data file path
     *
     * @param filename - messaged filename: hex(md5(data)) + ext
     * @return "/sdcard/chat.dim.sechat/tmp/upload/{filename}"
     */
    public String getUploadFilePath(String filename) {
        String dir = getTemporaryDirectory();
        return Paths.append(dir, "upload", filename);
    }

    /**
     *  Encrypted data file path
     *
     * @param filename - messaged filename: hex(md5(data)) + ext
     * @return "/sdcard/chat.dim.sechat/tmp/download/{filename}"
     */
    public String getDownloadFilePath(String filename) {
        String dir = getTemporaryDirectory();
        return Paths.append(dir, "download", filename);
    }
}
