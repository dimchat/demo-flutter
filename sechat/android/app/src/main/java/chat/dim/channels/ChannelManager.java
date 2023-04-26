package chat.dim.channels;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.common.StandardMethodCodec;

final class ChannelNames {

    static final String SESSION = "chat.dim/session";

    static final String FILE_TRANSFER = "chat.dim/ftp";
}

final class ChannelMethods {

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

    static final String PACK_DATA = "packData";
    static final String UNPACK_DATA = "unpackData";

    //
    //  FTP Channel
    //
    static final String SET_UPLOAD_API = "setUploadAPI";
    static final String SET_ROOT_DIRECTORY = "setRootDirectory";

    static final String UPLOAD_AVATAR = "uploadAvatar";
    static final String UPLOAD_FILE = "uploadEncryptFile";
    static final String DOWNLOAD_AVATAR = "downloadAvatar";
    static final String DOWNLOAD_FILE = "downloadEncryptedFile";

    static final String ON_UPLOAD_SUCCESS = "onUploadSuccess";
    static final String ON_UPLOAD_FAILURE = "onUploadFailed";
    static final String ON_DOWNLOAD_SUCCESS = "onDownloadSuccess";
    static final String ON_DOWNLOAD_FAILURE = "onDownloadFailed";
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
    public SessionChannel sessionChannel = null;
    public FileTransferChannel fileChannel = null;

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
        if (fileChannel == null) {
            fileChannel = new FileTransferChannel(messenger, ChannelNames.FILE_TRANSFER, codec);
        }
    }
}
