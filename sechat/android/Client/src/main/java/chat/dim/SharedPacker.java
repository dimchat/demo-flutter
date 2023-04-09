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
package chat.dim;

import java.io.IOException;

import chat.dim.crypto.SymmetricKey;
import chat.dim.protocol.Content;
import chat.dim.protocol.FileContent;
import chat.dim.protocol.ID;
import chat.dim.protocol.InstantMessage;
import chat.dim.protocol.ReliableMessage;
import chat.dim.protocol.SecureMessage;

public class SharedPacker extends ClientMessagePacker {

    public static final int MTP_JSON = 0x01;
    public static final int MTP_DMTP = 0x02;

    // Message Transfer Protocol
    public int mtpFormat = MTP_JSON;

    public SharedPacker(Facebook facebook, Messenger messenger) {
        super(facebook, messenger);
    }

    @Override
    public byte[] serializeMessage(ReliableMessage rMsg) {
        Compatible.fixMetaAttachment(rMsg);
        if (mtpFormat == MTP_JSON) {
            // JsON
            return super.serializeMessage(rMsg);
        } else {
            // D-MTP
            assert false : "D-MTP not support yet";
            return null;
        }
    }

    @Override
    public ReliableMessage deserializeMessage(byte[] data) {
        if (data == null || data.length < 2) {
            return null;
        }
        ReliableMessage rMsg;
        if (data[0] == '{') {
            // JsON
            rMsg = super.deserializeMessage(data);
        } else {
            // D-MTP
            assert false : "D-MTP not support yet";
            rMsg = null;
        }
        if (rMsg != null) {
            Compatible.fixMetaAttachment(rMsg);
        }
        return rMsg;
    }

    @Override
    public SecureMessage encryptMessage(InstantMessage iMsg) {
        // make sure visa.key exists before encrypting message
        Content content = iMsg.getContent();
        if (content instanceof FileContent) {
            if (content.get("data") != null/* && content.get("URL") == null*/) {
                ID sender = iMsg.getSender();
                ID receiver = iMsg.getReceiver();
                Messenger messenger = getMessenger();
                SymmetricKey key = messenger.getCipherKey(sender, receiver, true);
                assert key != null : "failed to get msg key for: " + sender + " -> " + receiver;
                // call emitter to encrypt & upload file data before send out
                GlobalVariable shared = GlobalVariable.getInstance();
                try {
                    shared.emitter.sendFileContentMessage(iMsg, key);
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
                return null;
            }
        }

        SecureMessage sMsg = super.encryptMessage(iMsg);
        ID receiver = iMsg.getReceiver();
        if (receiver.isGroup()) {
            // reuse group message keys
            ID sender = iMsg.getSender();
            Messenger messenger = getMessenger();
            SymmetricKey key = messenger.getCipherKey(sender, receiver, false);
            assert key != null : "failed to get msg key for: " + sender + " -> " + receiver;
            key.put("reused", true);
        }
        // TODO: reuse personal message key?

        return sMsg;
    }

    @Override
    public InstantMessage decryptMessage(SecureMessage sMsg) {
        InstantMessage iMsg = super.decryptMessage(sMsg);
        if (iMsg != null) {
            Content content = iMsg.getContent();
            if (content instanceof FileContent) {
                if (content.get("data") == null && content.get("URL") != null) {
                    ID sender = iMsg.getSender();
                    ID receiver = iMsg.getReceiver();
                    Messenger messenger = getMessenger();
                    SymmetricKey key = messenger.getCipherKey(sender, receiver, false);
                    assert key != null : "failed to get password: " + sender + " -> " + receiver;
                    // keep password to decrypt data after downloaded
                    ((FileContent) content).setPassword(key);
                }
            }
        }
        return iMsg;
    }
}
