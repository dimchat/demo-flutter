package chat.dim.channels;

import androidx.annotation.NonNull;

import java.util.Map;

import chat.dim.utils.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import chat.dim.format.Base64;
import chat.dim.protocol.ReliableMessage;

public class SessionChannelHandler implements MethodChannel.MethodCallHandler {

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (call.method.equals(ChannelMethods.SEND_MESSAGE_PACKAGE)) {
            Object msg = call.argument("msg");
            Object data = call.argument("data");
            Object prior = call.argument("priority");
            assert msg instanceof Map : "message error: " + msg;
            assert data instanceof String : "message data error: " + data;
            assert  prior instanceof Integer : "priority error: " + prior;

            ReliableMessage rMsg = ReliableMessage.parse(msg);
            byte[] pack = Base64.decode((String) data);

            Log.info("sending (" + pack.length + " bytes): " + rMsg + ", priority: " + prior);
            // TODO:

            result.success(null);
        } else {
            result.notImplemented();
        }
    }

}