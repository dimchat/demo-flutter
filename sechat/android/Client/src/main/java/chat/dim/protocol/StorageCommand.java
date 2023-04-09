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
package chat.dim.protocol;

import java.util.Arrays;
import java.util.Map;

import chat.dim.crypto.DecryptKey;
import chat.dim.crypto.PrivateKey;
import chat.dim.crypto.SymmetricKey;
import chat.dim.dkd.cmd.BaseCommand;
import chat.dim.format.Base64;
import chat.dim.format.JSON;
import chat.dim.format.UTF8;

/**
 *  Command message: {
 *      type : 0x88,
 *      sn   : 123,
 *
 *      command : "storage",
 *      title   : "key name",  // "contacts", "private_key", ...
 *
 *      data    : "...",       // base64_encode(symmetric)
 *      key     : "...",       // base64_encode(asymmetric)
 *
 *      // -- extra info
 *      //...
 *  }
 */
public class StorageCommand extends BaseCommand {

    public static final String STORAGE = "storage";

    // storage titles (should be encrypted)
    public static final String CONTACTS = "contacts";
    public static final String PRIVATE_KEY = "private_key";
    //...

    private String title;

    private byte[] data;
    private byte[] key;

    private byte[] plaintext;
    private SymmetricKey password;

    public StorageCommand(Map<String, Object> content) {
        super(content);
        // lazy
        title = null;
        data = null;
        key = null;
        plaintext = null;
        password = null;
    }

    public StorageCommand(String name) {
        super(STORAGE);
        title = name;
        data = null;
        key = null;
        plaintext = null;
        password = null;
    }

    public String getTitle() {
        if (title == null) {
            title = (String) get("title");
            if (title == null || title.length() == 0) {
                // (compatible with v1.0)
                //  contacts command: {
                //      command : 'contacts',
                //      data    : '...',
                //      key     : '...'
                //  }
                title = getCmd();
                assert !title.equalsIgnoreCase(STORAGE) : "title error: " + title;
            }
        }
        return title;
    }

    private void setTitle(String text) {
        put("title", text);
        title = text;
    }

    // user ID
    public ID getIdentifier() {
        return ID.parse(get("ID"));
    }

    public void setIdentifier(ID identifier) {
        if (identifier == null) {
            remove("ID");
        } else {
            put("ID", identifier.toString());
        }
    }

    //
    //  Encrypted data
    //      encrypted by a random password before upload
    //
    public byte[] getData() {
        if (data == null) {
            String base64 = (String) get("data");
            if (base64 != null) {
                data = Base64.decode(base64);
            }
        }
        return data;
    }

    public void setData(byte[] value) {
        if (value == null) {
            remove("data");
        } else {
            put("data", Base64.encode(value));
        }
        data = value;
        plaintext = null;
    }

    //
    //  Symmetric key
    //      password to decrypt data
    //      encrypted by user's public key before upload.
    //      this should be empty when the storage data is "private_key".
    //
    public byte[] getKey() {
        if (key == null) {
            String base64 = (String) get("key");
            if (base64 != null) {
                key = Base64.decode(base64);
            }
        }
        return key;
    }

    public void setKey(byte[] value) {
        if (value == null) {
            remove("key");
        } else {
            put("key", Base64.encode(value));
        }
        key = value;
        password = null;
    }

    //-------- Decryption

    public byte[] decrypt(SymmetricKey key) {
        if (plaintext == null) {
            if (key == null) {
                throw new NullPointerException("symmetric key empty");
            }
            byte[] data = getData();
            if (data == null) {
                return null;
            }
            plaintext = key.decrypt(data);
        }
        return plaintext;
    }

    public byte[] decrypt(PrivateKey privateKey) {
        if (password == null) {
            if (privateKey instanceof DecryptKey) {
                password = decryptKey((DecryptKey) privateKey);
            } else {
                throw new IllegalArgumentException("private key error: " + privateKey);
            }
        }
        return decrypt(password);
    }

    private SymmetricKey decryptKey(DecryptKey privateKey) {
        byte[] data = getKey();
        if (data == null) {
            return null;
        }
        byte[] key = privateKey.decrypt(data);
        if (key == null) {
            throw new NullPointerException("failed to decrypt key: " + Arrays.toString(data));
        }
        Object info = JSON.decode(UTF8.decode(key));
        return SymmetricKey.parse(info);
    }
}
