package chat.dim.channels;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.common.StandardMethodCodec;

final class ChannelNames {

    static final String STORAGE = "chat.dim/fileManager";

    static final String SESSION = "chat.dim/session";
}

final class ChannelMethods {

    //
    //  Storage channel
    //
    static final String CACHES_DIRECTORY = "cachesDirectory";
    static final String TEMPORARY_DIRECTORY = "temporaryDirectory";

    //
    //  Session channel
    //
    static final String CONNECT = "connect";
    static final String LOGIN = "login";
    static final String SET_SESSION_KEY = "setSessionKey";
    static final String GET_STATE = "getState";
    static final String SEND_MESSAGE_PACKAGE = "queueMessagePackage";

    static final String ON_STATE_CHANGED = "onStateChanged";
    static final String ON_RECEIVED = "onReceived";
}

public enum ChannelManager {

    INSTANCE;

    public static ChannelManager getInstance() {
        return INSTANCE;
    }

    ChannelManager() {

    }

    //
    //  Channels
    //
    private StorageChannel storageChannel = null;
    public SessionChannel sessionChannel = null;

    private static class MessageCodec extends StandardMessageCodec {
        @Override
        protected void writeValue(@NonNull ByteArrayOutputStream stream, @Nullable Object value) {
            if (value instanceof BigDecimal) {
                // FIXME:
                value = ((BigDecimal) value).doubleValue();
            }
            super.writeValue(stream, value);
        }
    }

    public void initChannels(BinaryMessenger messenger) {
        StandardMethodCodec codec = new StandardMethodCodec(new MessageCodec());
        if (sessionChannel == null) {
            sessionChannel = new SessionChannel(messenger, ChannelNames.SESSION, codec);
        }
        if (storageChannel == null) {
            storageChannel = new StorageChannel(messenger, ChannelNames.STORAGE, codec);
        }
    }
}
