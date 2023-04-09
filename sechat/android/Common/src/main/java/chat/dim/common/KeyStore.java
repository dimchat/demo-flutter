/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                                Written in 2019 by Moky <albert.moky@gmail.com>
 *
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
package chat.dim.common;

import java.util.HashMap;
import java.util.Map;

import chat.dim.crypto.PlainKey;
import chat.dim.crypto.SymmetricKey;
import chat.dim.database.MsgKeyTable;
import chat.dim.protocol.ID;

public final class KeyStore implements MsgKeyTable {

    private static final KeyStore ourInstance = new KeyStore();
    public static KeyStore getInstance() { return ourInstance; }
    private KeyStore() {
        super();
    }

    public MsgKeyTable keyTable = null;

    // memory caches
    private final Map<ID, Map<ID, SymmetricKey>> keyMap = new HashMap<>();

    //
    //  CipherKeyDelegate
    //

    @Override
    public SymmetricKey getCipherKey(ID sender, ID receiver, boolean generate) {
        if (receiver.isBroadcast()) {
            // broadcast message has no key
            return PlainKey.getInstance();
        }
        SymmetricKey key;
        // try from memory cache
        Map<ID, SymmetricKey> table = keyMap.get(sender);
        if (table == null) {
            table = new HashMap<>();
            keyMap.put(sender, table);
        } else {
            key = table.get(receiver);
            if (key != null) {
                return key;
            }
        }
        // try from database
        key = keyTable.getCipherKey(sender, receiver, generate);
        if (key != null) {
            // cache it
            table.put(receiver, key);
        } else if (generate) {
            // generate new key and store it
            key = SymmetricKey.generate(SymmetricKey.AES);
            keyTable.cacheCipherKey(sender, receiver, key);
            // cache it
            table.put(receiver, key);
        }
        return key;
    }

    @Override
    public void cacheCipherKey(ID sender, ID receiver, SymmetricKey key) {
        if (receiver.isBroadcast()) {
            // broadcast message has no key
            return;
        }
        // save into database
        keyTable.cacheCipherKey(sender, receiver, key);
        // store into memory cache
        Map<ID, SymmetricKey> table = keyMap.get(sender);
        if (table == null) {
            table = new HashMap<>();
            keyMap.put(sender, table);
        }
        table.put(receiver, key);
    }
}
