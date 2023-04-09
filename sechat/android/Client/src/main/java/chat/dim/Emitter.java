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
package chat.dim;

import java.io.IOException;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

import chat.dim.crypto.SymmetricKey;
import chat.dim.digest.MD5;
import chat.dim.dkd.BaseTextContent;
import chat.dim.format.Hex;
import chat.dim.http.FileTransfer;
import chat.dim.http.UploadRequest;
import chat.dim.model.Configuration;
import chat.dim.model.MessageDataSource;
import chat.dim.notification.Notification;
import chat.dim.notification.NotificationCenter;
import chat.dim.notification.NotificationNames;
import chat.dim.notification.Observer;
import chat.dim.protocol.AudioContent;
import chat.dim.protocol.Content;
import chat.dim.protocol.FileContent;
import chat.dim.protocol.ID;
import chat.dim.protocol.ImageContent;
import chat.dim.protocol.InstantMessage;
import chat.dim.protocol.ReliableMessage;
import chat.dim.protocol.TextContent;
import chat.dim.type.Pair;
import chat.dim.utils.Log;

public class Emitter implements Observer {

    private FileTransfer ftp = null;

    private final Map<String, InstantMessage> map = new HashMap<>();  // filename => task
    private final ReadWriteLock lock = new ReentrantReadWriteLock();

    Emitter() {
        super();
        NotificationCenter nc = NotificationCenter.getInstance();
        nc.addObserver(this, NotificationNames.FileUploadSuccess);
        nc.addObserver(this, NotificationNames.FileUploadFailure);
    }

    @Override
    protected void finalize() throws Throwable {
        NotificationCenter nc = NotificationCenter.getInstance();
        nc.removeObserver(this, NotificationNames.FileUploadFailure);
        nc.removeObserver(this, NotificationNames.FileUploadSuccess);
        super.finalize();
    }

    private FileTransfer getFileTransfer() {
        if (ftp == null) {
            ftp = FileTransfer.getInstance();
            Configuration config = Configuration.getInstance();
            ftp.api = config.getUploadURL();
            ftp.secret = config.getMD5Secret();
        }
        return ftp;
    }

    private void addTask(String filename, InstantMessage item) {
        Lock writeLock = lock.writeLock();
        writeLock.lock();
        try {
            map.put(filename, item);
        } finally {
            writeLock.unlock();
        }
    }
    private InstantMessage popTask(String filename) {
        InstantMessage item;
        Lock writeLock = lock.writeLock();
        writeLock.lock();
        try {
            item = map.get(filename);
            if (item != null) {
                map.remove(filename);
            }
        } finally {
            writeLock.unlock();
        }
        return item;
    }
    public void purge() {
        // TODO: remove expired messages in the map
    }

    @SuppressWarnings("unchecked")
    @Override
    public void onReceiveNotification(Notification notification) {
        String name = notification.name;
        Map<String, Object> info = notification.userInfo;
        if (name.equals(NotificationNames.FileUploadSuccess)) {
            UploadRequest request = (UploadRequest) info.get("request");
            Map<String, Object> response = (Map<String, Object>) info.get("response");
            URL url = (URL) response.get("url");
            onUploadSuccess(request, url);
        } else if (name.equals(NotificationNames.FileUploadFailure)) {
            UploadRequest request = (UploadRequest) info.get("request");
            IOException error = (IOException) info.get("error");
            onUploadFailed(request, error);
        }
    }

    //@Override
    private void onUploadSuccess(UploadRequest request, URL url) {
        Log.info("onUploadSuccess: " + request + ", url: " + url);
        String filename = FileTransfer.getFilename(request);
        InstantMessage iMsg = popTask(filename);
        if (iMsg == null) {
            Log.error("failed to get task: " + filename + ", url: " + url);
            return;
        }
        Log.info("get task for file: " + filename + ", url: " + url);
        // file data uploaded to FTP server, replace it with download URL
        // and send the content to station
        FileContent content = (FileContent) iMsg.getContent();
        //content.setData(null);
        content.setURL(url.toString());
        try {
            sendInstantMessage(iMsg);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    //@Override
    private void onUploadFailed(UploadRequest request, IOException error) {
        Log.error("onUploadFailed: " + request + ", error: " + error);
        String filename = FileTransfer.getFilename(request);
        InstantMessage iMsg = popTask(filename);
        if (iMsg == null) {
            Log.error("failed to get task: " + filename);
        } else {
            Log.info("get task for file: " + filename);
            // file data failed to upload, mark it error
            Map<String, Object> info = new HashMap<>();
            info.put("message", "failed to upload file");
            iMsg.put("error", info);
            try {
                saveInstantMessage(iMsg);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    private static void saveInstantMessage(InstantMessage iMsg) throws IOException {
        // save instant message
        MessageDataSource mds = MessageDataSource.getInstance();
        boolean ok = mds.saveInstantMessage(iMsg);
        if (!ok) {
            throw new IOException("failed to save message: " + iMsg);
        }
    }

    private void sendInstantMessage(InstantMessage iMsg) throws IOException {
        Log.info("send instant message (type=" + iMsg.getContent().getType() + "): "
                + iMsg.getSender() + " -> " + iMsg.getReceiver());
        // send by shared messenger
        GlobalVariable shared = GlobalVariable.getInstance();
        shared.messenger.sendInstantMessage(iMsg, 0);
        // save instant message
        saveInstantMessage(iMsg);
    }

    /**
     *  Send file content message with password
     *
     * @param iMsg     - outgoing message
     * @param password - key for encrypt/decrypt file data
     * @throws IOException on failed to save message
     */
    public void sendFileContentMessage(InstantMessage iMsg, SymmetricKey password) throws IOException {
        FileContent content = (FileContent) iMsg.getContent();
        // 1. save origin file data
        byte[] data = content.getData();
        String filename = content.getFilename();
        int len = FileTransfer.cacheFileData(data, filename);
        if (len != data.length) {
            Log.error("failed to save file data (len=" + data.length + "): " + filename);
            return;
        }
        // 2. save instant message without file data
        content.setData(null);
        saveInstantMessage(iMsg);
        // 3. add upload task with encrypted data
        byte[] encrypted = password.encrypt(data);
        filename = FileTransfer.getFilename(encrypted, filename);
        ID sender = iMsg.getSender();
        URL url = getFileTransfer().uploadEncryptData(encrypted, filename, sender);
        if (url == null) {
            // add task for upload
            addTask(filename, iMsg);
            Log.info("waiting upload filename: " + content.getFilename() + " -> " + filename);
        } else {
            // already upload before, set URL and send out immediately
            Log.info("uploaded filename: " + content.getFilename() + " -> " + filename + " => " + url);
            content.setURL(url.toString());
            sendInstantMessage(iMsg);
        }
    }

    /**
     *  Send text message to receiver
     *
     * @param text     - text message
     * @param receiver - receiver ID
     * @throws IOException on failed to save message
     */
    public void sendText(String text, ID receiver) throws IOException {
        TextContent content = new BaseTextContent(text);
        sendContent(content, receiver);
    }

    /**
     *  Send image message to receiver
     *
     * @param jpeg      - image data
     * @param thumbnail - image thumbnail
     * @param receiver  - receiver ID
     * @throws IOException on failed to save message
     */
    public void sendImage(byte[] jpeg, byte[] thumbnail, ID receiver) throws IOException {
        assert jpeg != null && jpeg.length > 0 : "image data empty";
        String filename = Hex.encode(MD5.digest(jpeg)) + ".jpeg";
        ImageContent content = FileContent.image(filename, jpeg);
        // add image data length & thumbnail into message content
        content.put("length", jpeg.length);
        content.setThumbnail(thumbnail);
        sendContent(content, receiver);
    }

    /**
     *  Send voice message to receiver
     *
     * @param mp4      - voice file
     * @param duration - length
     * @param receiver - receiver ID
     * @throws IOException on failed to save message
     */
    public void sendVoice(byte[] mp4, float duration, ID receiver) throws IOException {
        assert mp4 != null && mp4.length > 0 : "voice data empty";
        String filename = Hex.encode(MD5.digest(mp4)) + ".mp4";
        AudioContent content = FileContent.audio(filename, mp4);
        // add voice data length & duration into message content
        content.put("length", mp4.length);
        content.put("duration", duration);
        sendContent(content, receiver);
    }

    private void sendContent(Content content, ID receiver) throws IOException {
        assert receiver != null : "receiver should not empty";
        GlobalVariable shared = GlobalVariable.getInstance();
        Pair<InstantMessage, ReliableMessage> result;
        result = shared.messenger.sendContent(null, receiver, content, 0);
        if (result.second == null) {
            Log.warning("not send yet (type=" + content.getType() + "): " + receiver);
            return;
        }
        assert result.first != null : "failed to pack instant message: " + receiver;
        // save instant message
        saveInstantMessage(result.first);
    }
}
