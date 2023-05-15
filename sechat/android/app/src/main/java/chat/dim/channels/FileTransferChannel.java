package chat.dim.channels;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.io.IOError;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

import chat.dim.filesys.LocalCache;
import chat.dim.http.FileTransfer;
import chat.dim.http.DownloadDelegate;
import chat.dim.http.DownloadRequest;
import chat.dim.http.UploadDelegate;
import chat.dim.http.UploadRequest;
import chat.dim.http.UploadTask;
import chat.dim.protocol.ID;
import chat.dim.utils.Log;

public class FileTransferChannel extends MethodChannel implements UploadDelegate, DownloadDelegate {

    public FileTransferChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
        super(messenger, name, codec);
        setMethodCallHandler(new FileChannelHandler());
    }

    //-------- Upload Delegate

    private static Map<String, Object> uploadInfo(UploadRequest request) {
        Map<String, Object> info = new HashMap<>();
        // request info
        if (request instanceof UploadTask) {
            UploadTask task = (UploadTask) request;
            info.put("api", request.url.toString());
            info.put("name", request.name);
            info.put("filename", task.filename);
        } else {
            info.put("api", request.url.toString());
            info.put("path", request.path);
            info.put("name", request.name);
            info.put("sender", request.sender.toString());
        }
        return info;
    }

    @Override
    public void onUploadSuccess(UploadRequest request, URL url) {
        Log.info("onUploadSuccess: " + request + ", url: " + url);
        Map<String, Object> response = new HashMap<>();
        response.put("url", url.toString());
        Map<String, Object> params = uploadInfo(request);
        params.put("response", response);
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_UPLOAD_SUCCESS, params));
    }

    @Override
    public void onUploadFailed(UploadRequest request, IOException error) {
        Log.error("onUploadFailed: " + request + ", error: " + error);
        Map<String, Object> params = uploadInfo(request);
        params.put("error", error.toString());
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_UPLOAD_FAILURE, params));
    }

    @Override
    public void onUploadError(UploadRequest request, IOError error) {
        Log.error("onUploadError: " + request + ", error: " + error);
        Map<String, Object> params = uploadInfo(request);
        params.put("error", error.toString());
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_UPLOAD_FAILURE, params));
    }

    //-------- Download Delegate

    @Override
    public void onDownloadSuccess(DownloadRequest request, String path) {
        Log.info("onDownloadSuccess: " + request + ", path: " + path);
        Map<String, Object> params = new HashMap<>();
        params.put("url", request.url.toString());
        params.put("path", request.path);
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_DOWNLOAD_SUCCESS, params));
    }

    @Override
    public void onDownloadFailed(DownloadRequest request, IOException error) {
        Log.info("onDownloadFailed: " + request + ", error: " + error);
        Map<String, Object> params = new HashMap<>();
        params.put("url", request.url.toString());
        params.put("path", request.path);
        params.put("error", error.toString());
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_DOWNLOAD_FAILURE, params));
    }

    @Override
    public void onDownloadError(DownloadRequest request, IOError error) {
        Log.info("onDownloadFailed: " + request + ", error: " + error);
        Map<String, Object> params = new HashMap<>();
        params.put("url", request.url.toString());
        params.put("path", request.path);
        params.put("error", error.toString());
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_DOWNLOAD_FAILURE, params));
    }

    static class FileChannelHandler implements MethodChannel.MethodCallHandler {

        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            FileTransfer ftp = FileTransfer.getInstance();
            switch (call.method) {
                case ChannelMethods.DOWNLOAD_FILE: {
                    URL url = getURL(call);
                    String path = ftp.downloadEncryptedFile(url);
                    result.success(path);
                    break;
                }
                case ChannelMethods.DOWNLOAD_AVATAR: {
                    URL url = getURL(call);
                    String path = ftp.downloadAvatar(url);
                    result.success(path);
                    break;
                }
                case ChannelMethods.UPLOAD_FILE: {
                    byte[] data = call.argument("data");
                    String filename = call.argument("filename");
                    ID sender = ID.parse(call.argument("sender"));
                    URL url = ftp.uploadEncryptData(data, filename, sender);
                    result.success(url == null ? null : url.toString());
                    break;
                }
                case ChannelMethods.UPLOAD_AVATAR: {
                    byte[] data = call.argument("data");
                    String filename = call.argument("filename");
                    ID sender = ID.parse(call.argument("sender"));
                    URL url = ftp.uploadAvatar(data, filename, sender);
                    result.success(url == null ? null : url.toString());
                    break;
                }
                case ChannelMethods.SET_UPLOAD_API: {
                    ftp.api = call.argument("api");
                    ftp.secret = call.argument("secret");
                    result.success(null);
                    break;
                }
                case ChannelMethods.GET_CACHES_DIRECTORY: {
                    LocalCache localCache = LocalCache.getInstance();
                    String dir = localCache.getCachesDirectory();
                    result.success(dir);
                    break;
                }
                case ChannelMethods.GET_TEMPORARY_DIRECTORY: {
                    LocalCache localCache = LocalCache.getInstance();
                    String dir = localCache.getTemporaryDirectory();
                    result.success(dir);
                    break;
                }
                default:
                    result.notImplemented();
                    break;
            }
        }

        private URL getURL(MethodCall call) {
            String urlString = call.argument("url");
            try {
                return new URL(urlString);
            } catch (MalformedURLException e) {
                Log.error("URL error: " + e);
                return null;
            }
        }

    }
}
