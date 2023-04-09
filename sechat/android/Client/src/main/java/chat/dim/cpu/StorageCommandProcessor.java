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
package chat.dim.cpu;

import java.util.List;
import java.util.Map;

import chat.dim.Facebook;
import chat.dim.Messenger;
import chat.dim.crypto.Password;
import chat.dim.crypto.PrivateKey;
import chat.dim.crypto.SymmetricKey;
import chat.dim.format.JSON;
import chat.dim.format.UTF8;
import chat.dim.mkm.User;
import chat.dim.protocol.Content;
import chat.dim.protocol.ID;
import chat.dim.protocol.ReliableMessage;
import chat.dim.protocol.StorageCommand;

public class StorageCommandProcessor extends BaseCommandProcessor {

    public StorageCommandProcessor(Facebook facebook, Messenger messenger) {
        super(facebook, messenger);
    }

    private Object decryptData(StorageCommand content, SymmetricKey password) {
        // 1. get encrypted data
        byte[] data = content.getData();
        if (data == null) {
            throw new NullPointerException("data not found: " + content);
        }
        // 2. decrypt data
        data = password.decrypt(data);
        if (data == null) {
            throw new NullPointerException("failed to decrypt data: " + content);
        }
        // 3. decode data
        return JSON.decode(UTF8.decode(data));
    }

    @SuppressWarnings("unchecked")
    private Object decryptData(StorageCommand content) {
        // 1. get encrypt key
        byte[] key = content.getKey();
        if (key == null) {
            throw new NullPointerException("key not found: " + content);
        }
        // 2. get user ID
        ID identifier = content.getIdentifier();
        if (identifier == null) {
            throw new NullPointerException("ID not found: " + content);
        }
        // 3. decrypt key
        Facebook facebook = getFacebook();
        User user = facebook.getUser(identifier);
        key = user.decrypt(key);
        if (key == null) {
            throw new NullPointerException("failed to decrypt key: " + content);
        }
        // 4. decode key
        Object dict = JSON.decode(UTF8.decode(key));
        SymmetricKey password = SymmetricKey.parse((Map<String, Object>) dict);
        // 5. decrypt data
        return decryptData(content, password);
    }

    //---- Contacts

    private List<Content> saveContacts(List<String> contacts, ID user) {
        // TODO: save contacts when import your account in a new app
        return null;
    }

    // decrypt and save contacts for user
    @SuppressWarnings("unchecked")
    private List<Content> processContacts(StorageCommand content) {
        List<String> contacts = (List<String>) content.get("contacts");
        if (contacts == null) {
            contacts = (List<String>) decryptData(content);
            if (contacts == null) {
                throw new NullPointerException("failed to decrypt contacts: " + content);
            }
        }
        ID identifier = content.getIdentifier();
        return saveContacts(contacts, identifier);
    }

    //---- Private Key

    private List<Content> savePrivateKey(PrivateKey key, ID user) {
        // TODO: save private key when import your accounts from network
        return null;
    }

    @SuppressWarnings("unchecked")
    private List<Content> processPrivateKey(StorageCommand content) {
        String string = "<TODO: input your password>";
        SymmetricKey password = Password.generate(string);
        Object dict = decryptData(content, password);
        PrivateKey key = PrivateKey.parse((Map<String, Object>) dict);
        if (key == null) {
            throw new NullPointerException("failed to decrypt private key: " + content);
        }
        ID identifier = content.getIdentifier();
        return savePrivateKey(key, identifier);
    }

    @Override
    public List<Content> process(Content content, ReliableMessage rMsg) {
        assert content instanceof StorageCommand : "storage command error: " + content;
        StorageCommand command = (StorageCommand) content;
        String title = command.getTitle();
        if (title.equals(StorageCommand.CONTACTS)) {
            return processContacts(command);
        } else if (title.equals(StorageCommand.PRIVATE_KEY)) {
            return processPrivateKey(command);
        }
        throw new UnsupportedOperationException("Unsupported storage, title: " + title);
    }
}
