/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2019 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * ==============================================================================
 */
package chat.dim.model;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import chat.dim.Anonymous;
import chat.dim.GlobalVariable;
import chat.dim.SharedFacebook;
import chat.dim.database.MessageTable;
import chat.dim.mkm.User;
import chat.dim.notification.NotificationCenter;
import chat.dim.notification.NotificationNames;
import chat.dim.protocol.Document;
import chat.dim.protocol.Envelope;
import chat.dim.protocol.ID;
import chat.dim.protocol.InstantMessage;
import chat.dim.protocol.Message;
import chat.dim.protocol.ReceiptCommand;
import chat.dim.type.Time;

public final class ConversationDatabase extends MessageBuilder {

    private static final ConversationDatabase ourInstance = new ConversationDatabase();
    public static ConversationDatabase getInstance() { return ourInstance; }
    private ConversationDatabase() {
        super();
    }

    public MessageTable messageTable = null;

    public String getTimeString(Message msg) {
        Date time = msg.getTime();
        if (time == null) {
            return null;
        }
        return Time.getTimeString(time);
    }

    private SharedFacebook getFacebook() {
        GlobalVariable shared = GlobalVariable.getInstance();
        return shared.facebook;
    }

    @Override
    public String getName(ID identifier) {
        // get name from document
        Document doc = getFacebook().getDocument(identifier, "*");
        if (doc != null) {
            String name = doc.getName();
            if (name != null && name.length() > 0) {
                return name;
            }
        }
        // get name from ID
        return Anonymous.getName(identifier);
    }

    //-------- ConversationDataSource

    public int numberOfConversations() {
        return messageTable.numberOfConversations();
    }

    public ID conversationAtIndex(int index) {
        return messageTable.conversationAtIndex(index);
    }

    public boolean removeConversationAtIndex(int index) {
        ID chat = messageTable.conversationAtIndex(index);
        if (!messageTable.removeConversationAtIndex(index)) {
            return false;
        }
        postMessageUpdatedNotification(null, chat);
        return true;
    }

    public boolean removeConversation(ID identifier) {
        if (!messageTable.removeConversation(identifier)) {
            return false;
        }
        if (!messageTable.removeConversation(identifier)) {
            return false;
        }
        postMessageUpdatedNotification(null, identifier);
        return true;
    }

    public boolean clearConversation(ID identifier) {
        if (!messageTable.removeConversation(identifier)) {
            return false;
        }
        postMessageUpdatedNotification(null, identifier);
        return true;
    }

    // messages

    public int numberOfMessages(Conversation chatBox) {
        return messageTable.numberOfMessages(chatBox.identifier);
    }

    public int numberOfUnreadMessages(Conversation chatBox) {
        return messageTable.numberOfUnreadMessages(chatBox.identifier);
    }

    public boolean clearUnreadMessages(Conversation chatBox) {
        return messageTable.clearUnreadMessages(chatBox.identifier);
    }

    public InstantMessage lastMessage(Conversation chatBox) {
        return messageTable.lastMessage(chatBox.identifier);
    }

    public InstantMessage lastReceivedMessage() {
        User user = getFacebook().getCurrentUser();
        if (user == null) {
            return null;
        }
        return messageTable.lastReceivedMessage(user.getIdentifier());
    }

    public InstantMessage messageAtIndex(int index, Conversation chatBox) {
        return messageTable.messageAtIndex(index, chatBox.identifier);
    }

    private void postMessageUpdatedNotification(InstantMessage iMsg, ID identifier) {
        Map<String, Object> userInfo = new HashMap<>();
        userInfo.put("ID", identifier);
        userInfo.put("msg", iMsg);
        NotificationCenter nc = NotificationCenter.getInstance();
        nc.postNotification(NotificationNames.MessageUpdated, this, userInfo);
    }

    public boolean insertMessage(InstantMessage iMsg, Conversation chatBox) {
        boolean OK = messageTable.insertMessage(iMsg, chatBox.identifier);
        if (OK) {
            postMessageUpdatedNotification(iMsg, chatBox.identifier);
        }
        return OK;
    }

    public boolean removeMessage(InstantMessage iMsg, Conversation chatBox) {
        boolean OK = messageTable.removeMessage(iMsg, chatBox.identifier);
        if (OK) {
            postMessageUpdatedNotification(iMsg, chatBox.identifier);
        }
        return OK;
    }

    public boolean withdrawMessage(InstantMessage iMsg, Conversation chatBox) {
        boolean OK = messageTable.withdrawMessage(iMsg, chatBox.identifier);
        if (OK) {
            postMessageUpdatedNotification(iMsg, chatBox.identifier);
        }
        return OK;
    }

    public boolean saveReceipt(InstantMessage iMsg, Conversation chatBox) {
        boolean OK = messageTable.saveReceipt(iMsg, chatBox.identifier);
        if (OK) {
            ID entity = chatBox.identifier;
            // FIXME: check for origin conversation
            if (entity.isUser()) {
                ReceiptCommand receipt = (ReceiptCommand) iMsg.getContent();
                Envelope env = receipt.getOriginalEnvelope();
                if (env != null) {
                    ID sender = env.getSender();
                    if (sender != null && sender.equals(iMsg.getReceiver())) {
                        entity = env.getReceiver();
                    }
                }
            }
            postMessageUpdatedNotification(iMsg, entity);
        }
        return OK;
    }
}
