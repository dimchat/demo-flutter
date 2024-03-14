package chat.dim.channels;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

import chat.dim.filesys.LocalCache;

public class FileTransferChannel extends MethodChannel {

    public FileTransferChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
        super(messenger, name, codec);
        setMethodCallHandler(new FileChannelHandler());
    }

    static class FileChannelHandler implements MethodChannel.MethodCallHandler {

        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            switch (call.method) {
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

    }
}
