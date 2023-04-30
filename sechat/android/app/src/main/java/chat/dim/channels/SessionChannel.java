package chat.dim.channels;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.net.SocketAddress;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

import chat.dim.protocol.ID;
import chat.dim.protocol.ReliableMessage;
import chat.dim.network.ClientSession;
import chat.dim.network.SessionState;
import chat.dim.mtp.MTPHelper;
import chat.dim.mtp.Package;
import chat.dim.pack.SeekerResult;
import chat.dim.sechat.SessionController;
import chat.dim.type.Data;
import chat.dim.utils.Log;

public class SessionChannel extends MethodChannel {

    public SessionChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
        super(messenger, name, codec);
        setMethodCallHandler(new SessionChannelHandler());
    }

    static private int getStateIndex(SessionState state) {
        return state == null ? 0 : state.index;
    }

    public void onStateChanged(SessionState previous, SessionState current, long now) {
        Map<String, Object> params = new HashMap<>();
        params.put("previous", getStateIndex(previous));
        params.put("current", getStateIndex(current));
        params.put("now", now);
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_STATE_CHANGED, params));
    }

    public void onReceived(byte[] pack, SocketAddress remote) {
        Map<String, Object> params = new HashMap<>();
        params.put("payload", pack);
        params.put("remote", remote.toString());
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_RECEIVED, params));
    }

    static class SessionChannelHandler implements MethodChannel.MethodCallHandler {

        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            String method = call.method;
            switch (method) {
                case ChannelMethods.SEND_MESSAGE_PACKAGE: {
                    Map<String, Object> msg = call.argument("msg");
                    byte[] data = call.argument("data");
                    Integer prior = call.argument("priority");
                    assert data != null : "message data empty";
                    // call
                    queueMessagePackage(msg, data, prior);
                    result.success(null);
                    break;
                }
                case ChannelMethods.GET_STATE: {
                    int state = getState();
                    result.success(state);
                    break;
                }
                case ChannelMethods.CONNECT: {
                    String host = call.argument("host");
                    Integer port = call.argument("port");
                    // call
                    connect(host, port);
                    result.success(null);
                    break;
                }
                case ChannelMethods.LOGIN: {
                    String user = call.argument("user");
                    // call
                    result.success(login(user));
                    break;
                }
                case ChannelMethods.SET_SESSION_KEY: {
                    String sessionKey = call.argument("session");
                    // call
                    setSessionKey(sessionKey);
                    result.success(null);
                    break;
                }
                case ChannelMethods.PACK_DATA: {
                    byte[] payload = call.argument("payload");
                    assert payload != null : "payload empty";
                    // call
                    byte[] pack = packData(payload);
                    result.success(pack);
                    break;
                }
                case ChannelMethods.UNPACK_DATA: {
                    byte[] data = call.argument("data");
                    assert data != null : "data empty";
                    // call
                    Map<String, Object> info = new HashMap<>();
                    SeekerResult<Package> res = unpackData(data);
                    if (res.offset < 0) {
                        // data error, drop the whole buffer
                        info.put("position", data.length);
                    } else if (res.value == null) {
                        info.put("position", res.offset);
                    } else {
                        info.put("position", res.offset + res.value.getSize());
                        info.put("payload", res.value.body.getBytes());
                    }
                    result.success(info);
                    break;
                }
                default: {
                    result.notImplemented();
                    break;
                }
            }
        }

        private byte[] packData(byte[] payload) {
            Log.info("packing payload: " + payload.length + " bytes");
            Package pack = MTPHelper.createMessage(null, new Data(payload));
            return pack.getBytes();
        }
        private SeekerResult<Package> unpackData(byte[] data) {
            Log.info("unpacking data: " + data.length + " bytes");
            SeekerResult<Package> res = MTPHelper.seekPackage(new Data(data));
            if (res.value == null) {
                Log.info("got nothing, offset: " + res.offset);
            } else {
                Log.info("got package length: " + res.value.getSize() + ", payload: "
                        + res.value.body.getSize() + ", offset: " + res.offset);
            }
            return res;
        }

        private void queueMessagePackage(Map<String, Object> msg, byte[] data, Integer prior) {
            ReliableMessage rMsg = ReliableMessage.parse(msg);
            Log.info("sending (" + data.length + " bytes): " + rMsg + ", priority: " + prior);

            SessionController controller = SessionController.getInstance();
            ClientSession session = controller.session;
            if (session == null) {
                Log.error("session not start yet");
            } else {
                session.queueMessagePackage(rMsg, data, prior);
            }
        }

        private int getState() {
            SessionController controller = SessionController.getInstance();
            SessionState state = controller.getState();
            Log.info("session state: " + state);
            return getStateIndex(state);
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
