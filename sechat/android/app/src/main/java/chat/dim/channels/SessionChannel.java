package chat.dim.channels;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.net.SocketAddress;
import java.util.HashMap;
import java.util.Map;

import chat.dim.format.UTF8;
import chat.dim.protocol.ID;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

import chat.dim.format.Base64;
import chat.dim.protocol.ReliableMessage;
import chat.dim.network.ClientSession;
import chat.dim.network.SessionState;
import chat.dim.sechat.SessionController;
import chat.dim.utils.Log;

public class SessionChannel extends MethodChannel {

    public SessionChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
        super(messenger, name, codec);
        setMethodCallHandler(new SessionChannelHandler());
    }

    public void onStateChanged(SessionState previous, SessionState current, long now) {
        Map<String, Object> params = new HashMap<>();
        params.put("previous", previous == null ? -1 : previous.index);
        params.put("current", current == null ? -1 : current.index);
        params.put("now", now);
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_STATE_CHANGED, params));
    }

    public void onReceived(byte[] pack, SocketAddress remote) {
        String json = UTF8.decode(pack);
        Map<String, Object> params = new HashMap<>();
        params.put("json", json);
        params.put("remote", remote.toString());
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_RECEIVED, params));
    }

    static class SessionChannelHandler implements MethodChannel.MethodCallHandler {

        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            String method = call.method;
            switch (method) {
                case ChannelMethods.SEND_MESSAGE_PACKAGE:
                    Map<String, Object> msg = call.argument("msg");
                    String data = call.argument("data");
                    Integer prior = call.argument("priority");
                    // call
                    queueMessagePackage(msg, data, prior);
                    result.success(null);
                    break;
                case ChannelMethods.GET_STATE:
                    int state = getState();
                    result.success(state);
                    break;
                case ChannelMethods.CONNECT:
                    String host = call.argument("host");
                    Integer port = call.argument("port");
                    // call
                    connect(host, port);
                    result.success(null);
                    break;
                case ChannelMethods.LOGIN:
                    String user = call.argument("user");
                    // call
                    result.success(login(user));
                    break;
                case ChannelMethods.SET_SESSION_KEY:
                    String sessionKey = call.argument("session");
                    // call
                    setSessionKey(sessionKey);
                    result.success(null);
                default:
                    result.notImplemented();
                    break;
            }
        }

        private void queueMessagePackage(Map<String, Object> msg, String data, Integer prior) {
            ReliableMessage rMsg = ReliableMessage.parse(msg);
            byte[] pack = Base64.decode((String) data);
            Log.info("sending (" + pack.length + " bytes): " + rMsg + ", priority: " + prior);

            SessionController controller = SessionController.getInstance();
            ClientSession session = controller.session;
            if (session == null) {
                Log.error("session not start yet");
            } else {
                session.queueMessagePackage(rMsg, pack, prior);
            }
        }

        private int getState() {
            SessionController controller = SessionController.getInstance();
            SessionState state = controller.getState();
            Log.info("session state: " + state);
            return state == null ? -1 : state.index;
        }

        private void connect(String host, Integer port) {
            Log.info("connecting (" + host + ":" + port + ")...");
            SessionController controller = SessionController.getInstance();
            controller.connect(host, port);
        }

        private boolean login(String user) {
            Log.info("login user: " + user);
            ID identifier = ID.parse(user);
            assert identifier != null : "user id error: " + user;
            SessionController controller = SessionController.getInstance();
            return controller.login(identifier);
        }

        private void setSessionKey(String sessionKey) {
            Log.info("session key: " + sessionKey);
            SessionController controller = SessionController.getInstance();
            controller.setSessionKey(sessionKey);
        }

    }
}
