package chat.dim.channels;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.common.StandardMethodCodec;

final class ChannelNames {

    static final String AUDIO = "chat.dim/audio";

    static final String FILE_TRANSFER = "chat.dim/ftp";
}

final class ChannelMethods {

    //
    //  Audio Channel
    //
    static final String START_RECORD = "startRecord";
    static final String STOP_RECORD = "stopRecord";
    static final String START_PLAY = "startPlay";
    static final String STOP_PLAY = "stopPlay";

    static final String ON_RECORD_FINISHED = "onRecordFinished";
    static final String ON_PLAY_FINISHED = "onPlayFinished";

    //
    //  FTP Channel
    //
    static final String SET_UPLOAD_API = "setUploadAPI";

    static final String UPLOAD_AVATAR = "uploadAvatar";
    static final String UPLOAD_FILE = "uploadEncryptFile";
    static final String DOWNLOAD_AVATAR = "downloadAvatar";
    static final String DOWNLOAD_FILE = "downloadEncryptedFile";

    static final String ON_UPLOAD_SUCCESS = "onUploadSuccess";
    static final String ON_UPLOAD_FAILURE = "onUploadFailed";
    static final String ON_DOWNLOAD_SUCCESS = "onDownloadSuccess";
    static final String ON_DOWNLOAD_FAILURE = "onDownloadFailed";

    static final String GET_CACHES_DIRECTORY = "getCachesDirectory";
    static final String GET_TEMPORARY_DIRECTORY = "getTemporaryDirectory";

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
    public AudioChannel audioChannel = null;
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
        System.out.println("initChannels: audioChannel=" + audioChannel);
        System.out.println("initChannels: fileChannel=" + fileChannel);
        StandardMethodCodec codec = new StandardMethodCodec(new MessageCodec());
        //if (audioChannel == null) {
            audioChannel = new AudioChannel(messenger, ChannelNames.AUDIO, codec);
        //}
        //if (fileChannel == null) {
            fileChannel = new FileTransferChannel(messenger, ChannelNames.FILE_TRANSFER, codec);
        //}
    }
}
