package chat.dim.channels;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

import chat.dim.filesys.LocalCache;

public class StorageChannel extends MethodChannel {

   public StorageChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
      super(messenger, name, codec);
      setMethodCallHandler(new StorageChannelHandler());
   }

   static class StorageChannelHandler implements MethodChannel.MethodCallHandler {

      @Override
      public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
         if (call.method.equals(ChannelMethods.CACHES_DIRECTORY)) {
            String dir = LocalCache.getInstance().getCachesDirectory();
            result.success(dir);
         } else if (call.method.equals(ChannelMethods.TEMPORARY_DIRECTORY)) {
            String dir = LocalCache.getInstance().getTemporaryDirectory();
            result.success(dir);
         } else {
            result.notImplemented();
         }
      }

   }
}
