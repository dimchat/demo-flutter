package chat.dim.channels;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

public class SessionChannel extends MethodChannel  {

   public SessionChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
      super(messenger, name, codec);
   }

   public void sendCommand(Map<String, Object> command, String receiver) {
      Map<String, Object> params = new HashMap<>();
      params.put("content", command);
      params.put("receiver", receiver);
      new Handler(Looper.getMainLooper()).post(() ->
              invokeMethod(ChannelMethods.SEND_COMMAND, params));
   }

   public void sendContent(Map<String, Object> content, String receiver) {
      Map<String, Object> params = new HashMap<>();
      params.put("content", content);
      params.put("receiver", receiver);
      new Handler(Looper.getMainLooper()).post(() ->
              invokeMethod(ChannelMethods.SEND_CONTENT, params));
   }

}
