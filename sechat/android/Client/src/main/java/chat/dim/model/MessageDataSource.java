/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2020 Albert Moky
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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import chat.dim.GlobalVariable;
import chat.dim.SharedFacebook;
import chat.dim.SharedMessenger;
import chat.dim.crypto.SymmetricKey;
import chat.dim.notification.Notification;
import chat.dim.notification.NotificationCenter;
import chat.dim.notification.NotificationNames;
import chat.dim.notification.Observer;
import chat.dim.port.Departure;
import chat.dim.protocol.BlockCommand;
import chat.dim.protocol.Content;
import chat.dim.protocol.ForwardContent;
import chat.dim.protocol.HandshakeCommand;
import chat.dim.protocol.ID;
import chat.dim.protocol.InstantMessage;
import chat.dim.protocol.LoginCommand;
import chat.dim.protocol.MetaCommand;
import chat.dim.protocol.MuteCommand;
import chat.dim.protocol.ReceiptCommand;
import chat.dim.protocol.ReliableMessage;
import chat.dim.protocol.ReportCommand;
import chat.dim.protocol.SearchCommand;
import chat.dim.protocol.group.InviteCommand;
import chat.dim.protocol.group.QueryCommand;
import chat.dim.utils.Log;

public class MessageDataSource implements Observer {

    private static final MessageDataSource ourInstance = new MessageDataSource();
    public static MessageDataSource getInstance() { return ourInstance; }
    private MessageDataSource() {
        super();

        NotificationCenter nc = NotificationCenter.getInstance();
        nc.addObserver(this, NotificationNames.MetaSaved);
        nc.addObserver(this, NotificationNames.DocumentUpdated);
    }

    @Override
    protected void finalize() throws Throwable {
        NotificationCenter nc = NotificationCenter.getInstance();
        nc.removeObserver(this, NotificationNames.MetaSaved);
        nc.removeObserver(this, NotificationNames.DocumentUpdated);
        super.finalize();
    }

    private final Map<ID, List<ReliableMessage>> incomingMessages = new HashMap<>();
    private final Map<ID, List<InstantMessage>> outgoingMessages = new HashMap<>();

    @Override
    public void onReceiveNotification(Notification notification) {
        String name = notification.name;
        Map<String, Object> info = notification.userInfo;
        assert name != null && info != null : "notification error: " + notification;
        if (name.equals(NotificationNames.MetaSaved) || name.equals(NotificationNames.DocumentUpdated)) {
            GlobalVariable shared = GlobalVariable.getInstance();
            SharedFacebook facebook = shared.facebook;
            SharedMessenger messenger = shared.messenger;
            ID entity = ID.parse(info.get("ID"));
            if (entity.isUser()) {
                // check user
                if (facebook.getPublicKeyForEncryption(entity) == null) {
                    Log.error("user not ready yet: " + entity);
                    return;
                }
            }

            // processing incoming messages
            List<ReliableMessage> incoming = incomingMessages.remove(entity);
            if (incoming != null) {
                List<ReliableMessage> responses;
                for (ReliableMessage item : incoming) {
                    responses = messenger.processReliableMessage(item);
                    if (responses == null || responses.size() == 0) {
                        continue;
                    }
                    for (ReliableMessage res : responses) {
                        messenger.sendReliableMessage(res, Departure.Priority.SLOWER.value);
                    }
                }
            }

            // processing outgoing messages
            List<InstantMessage> outgoing = outgoingMessages.remove(entity);
            if (outgoing != null) {
                for (InstantMessage item : outgoing) {
                    messenger.sendInstantMessage(item, Departure.Priority.SLOWER.value);
                }
            }
        }
    }

    public boolean saveInstantMessage(InstantMessage iMsg) {
        Content content = iMsg.getContent();
        // TODO: check message type
        //       only save normal message and group commands
        //       ignore 'Handshake', ...
        //       return true to allow responding

        if (content instanceof HandshakeCommand) {
            // handshake command will be processed by CPUs
            // no need to save handshake command here
            return true;
        }
        if (content instanceof ReportCommand) {
            // report command is sent to station,
            // no need to save report command here
            return true;
        }
        if (content instanceof LoginCommand) {
            // login command will be processed by CPUs
            // no need to save login command here
            return true;
        }
        if (content instanceof MetaCommand) {
            // meta & document command will be checked and saved by CPUs
            // no need to save meta & document command here
            return true;
        }
        if (content instanceof MuteCommand || content instanceof BlockCommand) {
            // TODO: create CPUs for mute & block command
            // no need to save mute & block command here
            return true;
        }
        if (content instanceof SearchCommand) {
            // search result will be parsed by CPUs
            // no need to save search command here
            return true;
        }
        if (content instanceof ForwardContent) {
            // forward content will be parsed, if secret message decrypted, save it
            // no need to save forward content itself
            return true;
        }

        if (content instanceof InviteCommand) {
            // send keys again
            ID me = iMsg.getReceiver();
            ID group = content.getGroup();
            GlobalVariable shared = GlobalVariable.getInstance();
            SymmetricKey key = shared.mdb.getCipherKey(me, group, false);
            if (key != null) {
                //key.put("reused", null);
                key.remove("reused");
            }
        }
        if (content instanceof QueryCommand) {
            // FIXME: same query command sent to different members?
            return true;
        }

        Amanuensis clerk = Amanuensis.getInstance();

        if (content instanceof ReceiptCommand) {
            return clerk.saveReceipt(iMsg);
        } else {
            return clerk.saveInstantMessage(iMsg);
        }
    }

    public void suspendMessage(ReliableMessage rMsg) {
        // save this message in a queue waiting sender's meta response
        ID waiting = ID.parse(rMsg.get("waiting"));
        if (waiting == null) {
            waiting = rMsg.getGroup();
            if (waiting == null) {
                waiting = rMsg.getSender();
            }
        } else {
            rMsg.remove("waiting");
        }
        List<ReliableMessage> list = incomingMessages.get(waiting);
        if (list == null) {
            list = new ArrayList<>();
            incomingMessages.put(waiting, list);
        }
        list.add(rMsg);
    }

    public void suspendMessage(InstantMessage iMsg) {
        // save this message in a queue waiting receiver's meta response
        ID waiting = ID.parse(iMsg.get("waiting"));
        if (waiting == null) {
            waiting = iMsg.getGroup();
            if (waiting == null) {
                waiting = iMsg.getSender();
            }
        } else {
            iMsg.remove("waiting");
        }
        List<InstantMessage> list = outgoingMessages.get(waiting);
        if (list == null) {
            list = new ArrayList<>();
            outgoingMessages.put(waiting, list);
        }
        list.add(iMsg);
    }
}
