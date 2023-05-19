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

import java.io.IOException;
import java.net.URL;

import chat.dim.channels.ChannelManager;
import chat.dim.channels.FileTransferChannel;
import chat.dim.digest.MD5;
import chat.dim.filesys.ExternalStorage;
import chat.dim.filesys.LocalCache;
import chat.dim.filesys.Paths;
import chat.dim.format.Hex;
import chat.dim.format.UTF8;
import chat.dim.protocol.ID;
import chat.dim.utils.Log;

public enum FileTransfer {

    INSTANCE;

    public static FileTransfer getInstance() {
        return INSTANCE;
    }

    // upload API
    public String api = "https://sechat.dim.chat/{ID}/upload?md5={MD5}&salt={SALT}";
    // upload key (hex)
    public String secret = "12345678";

    private final HTTPClient http;

    FileTransfer() {
        http = new HTTPClient() {
            @Override
            protected void cleanup() {
                // clean expired temporary files for upload/download
                long now = System.currentTimeMillis();
                LocalCache cache = LocalCache.getInstance();
                //cleanup(cache.getCachesDirectory(), now - CACHES_EXPIRES);
                ExternalStorage.cleanup(cache.getTemporaryDirectory(), now - TEMPORARY_EXPIRES);
            }
        };
        http.start();
    }
    //public static final long CACHES_EXPIRES = 365 * 24 * 3600 * 1000L;
    public static final long TEMPORARY_EXPIRES = 7 * 24 * 3600 * 1000L;

    private FileTransferChannel getChannel() {
        ChannelManager manager = ChannelManager.getInstance();
        return manager.fileChannel;
    }

    /**
     *  Upload avatar image data for user
     *
     * @param data     - image data
     * @param filename - image filename ('avatar.jpg')
     * @param sender   - user ID
     * @return remote URL if same file uploaded before
     */
    public URL uploadAvatar(byte[] data, String filename, ID sender) {
        //filename = Paths.filename(filename);
        filename = getFilename(data, filename);
        LocalCache cache = LocalCache.getInstance();
        String path = cache.getAvatarFilePath(filename);
        return upload(data, path, "avatar", sender);
    }

    /**
     *  Upload encrypted file data for user
     *
     * @param data     - encrypted data
     * @param filename - data file name ('voice.mp4')
     * @param sender   - user ID
     * @return remote URL if same file uploaded before
     */
    public URL uploadEncryptData(byte[] data, String filename, ID sender) {
        //filename = Paths.filename(filename);
        filename = getFilename(data, filename);
        LocalCache cache = LocalCache.getInstance();
        String path = cache.getUploadFilePath(filename);
        return upload(data, path, "file", sender);
    }

    private URL upload(byte[] data, String path, String var, ID sender) {
        try {
            URL url = new URL(api);
            byte[] key = Hex.decode(secret);
            return http.upload(url, key, data, path, var, sender, getChannel());
        } catch (IOException e) {
            Log.error("failed to upload file: " + path + " -> " +api);
            return null;
        }
    }

    private static boolean isEncoded(String filename, String ext) {
        if (ext != null) {
            filename = filename.substring(0, filename.length() - ext.length() - 1);
        }
        return filename.length() == 32 && filename.matches("^[\\dA-Fa-f]+$");
    }

    private static String getFilename(byte[] data, String filename) {
        // split file extension
        String ext = Paths.extension(filename);
        if (isEncoded(filename, ext)) {
            // already encoded
            return filename;
        }
        // get filename from data
        filename = Hex.encode(MD5.digest(data));
        if (ext == null) {
            return filename;
        }
        return filename + "." + ext;
    }

    private static String getFilename(URL url) {
        String urlString = url.toString();
        String filename = Paths.filename(urlString);
        byte[] data = UTF8.encode(urlString);
        return getFilename(data, filename);
    }

    /**
     *  Download avatar image file
     *
     * @param url      - avatar URL
     * @return local path if same file downloaded before
     */
    public String downloadAvatar(URL url) {
        String filename = getFilename(url);
        LocalCache cache = LocalCache.getInstance();
        String path = cache.getAvatarFilePath(filename);
        return http.download(url, path, getChannel());
    }

    /**
     *  Download encrypted file data for user
     *
     * @param url      - relay URL
     * @return temporary path if same file downloaded before
     */
    public String downloadEncryptedFile(URL url) {
        String filename = getFilename(url);
        LocalCache cache = LocalCache.getInstance();
        String path = cache.getDownloadFilePath(filename);
        return http.download(url, path, getChannel());
    }

}
