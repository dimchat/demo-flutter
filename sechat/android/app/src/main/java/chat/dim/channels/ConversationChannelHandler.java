package chat.dim.channels;

import androidx.annotation.NonNull;

import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import chat.dim.mkm.Station;
import chat.dim.protocol.Envelope;
import chat.dim.protocol.TextContent;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import chat.dim.GlobalVariable;
import chat.dim.SharedFacebook;
import chat.dim.database.MessageTable;
import chat.dim.model.ConversationDatabase;
import chat.dim.protocol.ID;
import chat.dim.protocol.InstantMessage;
import chat.dim.type.Pair;

public class ConversationChannelHandler implements MethodChannel.MethodCallHandler {

    List<Map<String, Object>> conversations = null;
    Map<ID, List<InstantMessage>> messagesCache = new HashMap<>();

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (call.method.equals(ChannelMethods.CONVERSATIONS_OF_USER)) {
            result.success(allConversations());
        } else if (call.method.equals(ChannelMethods.MESSAGES_OF_CONVERSATION)) {
            ID chatBox = ID.parse(call.argument("identifier"));
            assert chatBox != null : "conversation ID not found";
            List<InstantMessage> messages = allMessages(chatBox);
            result.success(revert(messages));
        } else {
            result.notImplemented();
        }
    }

    private static SharedFacebook getFacebook() {
        GlobalVariable shared = GlobalVariable.getInstance();
        return shared.facebook;
    }

    ConversationDatabase getDatabase() {
        return ConversationDatabase.getInstance();
    }

    private List<Map<String, Object>> revert(List<InstantMessage> messages) {
        List<Map<String, Object>> array = new ArrayList<>(messages.size());
        for (InstantMessage iMsg : messages) {
            array.add(iMsg.toMap());
        }
        return array;
    }

    private List<InstantMessage> allMessages(ID chatBox) {
        List<InstantMessage> messages = messagesCache.get(chatBox);
        if (messages == null) {
            MessageTable table = getDatabase().messageTable;
            int count = table.numberOfMessages(chatBox);
            InstantMessage iMsg;
            messages = new ArrayList<>(count);
            for (int index = 0; index < count; ++index) {
                iMsg = table.messageAtIndex(index, chatBox);
                if (iMsg != null) {
                    messages.add(iMsg);
                }
            }
            // TODO: test
            if (messages.size() == 0) {
                System.out.println("build test messages");
                iMsg = InstantMessage.create(
                        Envelope.create(ID.ANYONE, ID.EVERYONE, null),
                        TextContent.create("Hello " + ID.EVERYONE + "!")
                );
                messages.add(iMsg);
                iMsg = InstantMessage.create(
                        Envelope.create(ID.FOUNDER, ID.ANYONE, null),
                        TextContent.create("Hello " + ID.ANYONE + "!")
                );
                messages.add(iMsg);
                iMsg = InstantMessage.create(
                        Envelope.create(ID.FOUNDER, ID.EVERYONE, null),
                        TextContent.create("Hello " + ID.EVERYONE + "!")
                );
                messages.add(iMsg);
                iMsg = InstantMessage.create(
                        Envelope.create(Station.ANY, ID.FOUNDER, null),
                        TextContent.create("Hello " + ID.FOUNDER + "!")
                );
                messages.add(iMsg);
            }
            messagesCache.put(chatBox, messages);
        }
        return messages;
    }

    private List<Map<String, Object>> allConversations() {
        if (conversations == null) {
            SharedFacebook facebook = getFacebook();
            ConversationDatabase db = getDatabase();
            int count = db.numberOfConversations();
            ID cid;
            String name;
            String icon;
            Pair<String, URL> avatar;
            Map<String, Object> info;
            conversations = new ArrayList<>(count);
            for (int index = 0; index < count; ++index) {
                cid = db.conversationAtIndex(index);
                name = facebook.getName(cid);
                icon = null;
                if (cid.isUser()) {
                    avatar = facebook.getAvatar(cid);
                    if (avatar.first != null) {
                        icon = avatar.first;
                    } else if (avatar.second != null) {
                        icon = avatar.second.toString();
                    }
                }
                info = new HashMap<>();
                info.put("identifier", cid.toString());
                info.put("name", name);
                if (icon != null) {
                    info.put("icon", icon);
                }
                conversations.add(info);
            }
            // TODO: test
            if (conversations.size() == 0) {
                System.out.println("build test chat boxes");
                info = new HashMap<>();
                info.put("identifier", ID.ANYONE.toString());
                info.put("type", ID.ANYONE.getType());
                info.put("name", facebook.getName(ID.ANYONE));
                conversations.add(info);
                info = new HashMap<>();
                info.put("identifier", ID.EVERYONE.toString());
                info.put("type", ID.EVERYONE.getType());
                info.put("name", facebook.getName(ID.EVERYONE));
                conversations.add(info);
                info = new HashMap<>();
                info.put("identifier", ID.FOUNDER.toString());
                info.put("type", ID.FOUNDER.getType());
                info.put("name", facebook.getName(ID.FOUNDER));
                conversations.add(info);
                info = new HashMap<>();
                info.put("identifier", Station.ANY.toString());
                info.put("type", Station.ANY.getType());
                info.put("name", facebook.getName(Station.ANY));
                conversations.add(info);
            }
        }
        return conversations;
    }
}