package chat.dim.channels;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.common.StandardMethodCodec;

final class ChannelNames {

    static String MESSENGER = "chat.dim/messenger";

    static String CONVERSATION = "chat.dim/conversation";
}

final class ChannelMethods {

    //
    //  Messenger channel
    //

    //
    //  Conversation channel
    //
    static String CONVERSATIONS_OF_USER = "conversationsOfUser";
    static String MESSAGES_OF_CONVERSATION = "messagesOfConversation";
}

public enum ChannelManager {

    INSTANCE;

    public static ChannelManager getInstance() {
        return INSTANCE;
    }

    ChannelManager() {

    }

    private MethodChannel conversationChannel = null;

    private static MethodChannel createMethodChannel(BinaryMessenger messenger, String name,
                                                     MethodChannel.MethodCallHandler handler) {
        MethodChannel channel = new MethodChannel(messenger, name, new StandardMethodCodec(new MessageCodec()));
        channel.setMethodCallHandler(handler);
        return channel;
    }
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
        if (conversationChannel == null) {
            conversationChannel = createMethodChannel(messenger,
                    ChannelNames.CONVERSATION, new ConversationChannelHandler());
        }
    }
}
