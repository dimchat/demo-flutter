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
package chat.dim;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import chat.dim.crypto.PrivateKey;
import chat.dim.database.AddressNameTable;
import chat.dim.database.UserTable;
import chat.dim.dbi.AccountDBI;
import chat.dim.http.FileTransfer;
import chat.dim.mkm.User;
import chat.dim.protocol.Document;
import chat.dim.protocol.ID;
import chat.dim.protocol.Visa;
import chat.dim.type.Pair;

public final class SharedFacebook extends ClientFacebook {

    private final List<User> localUsers = new ArrayList<>();
    private final Map<ID, List<ID>> userContacts = new HashMap<>();

    public SharedFacebook(AccountDBI db) {
        super(db);
    }

    /**
     *  Get avatar for user
     *
     * @param user - user ID
     * @return cache path & remote URL
     */
    public Pair<String, URL> getAvatar(ID user) {
        String urlString = null;
        Document doc = getDocument(user, "*");
        if (doc != null) {
            if (doc instanceof Visa) {
                urlString = ((Visa) doc).getAvatar();
            } else {
                urlString = (String) doc.getProperty("avatar");
            }
        }
        String path = null;
        URL url = null;
        if (urlString != null && urlString.indexOf("://") > 0) {
            try {
                url = new URL(urlString);
                FileTransfer ftp = FileTransfer.getInstance();
                // TODO: observe notification: 'FileUploadSuccess'
                path = ftp.downloadAvatar(url);
            } catch (MalformedURLException e) {
                throw new RuntimeException(e);
            }
        }
        return new Pair<>(path, url);
    }

    public boolean savePrivateKey(PrivateKey key, String type, ID user) {
        AccountDBI db = getDatabase();
        return db.savePrivateKey(key, type, user);
    }

    //-------- Users

    @Override
    public List<User> getLocalUsers() {
        if (localUsers.size() == 0) {
            List<User> users = super.getLocalUsers();
            localUsers.addAll(users);
        }
        return localUsers;
    }

    public boolean addUser(ID user) {
        AccountDBI db = getDatabase();
        List<ID> allUsers = db.getLocalUsers();
        if (allUsers == null) {
            allUsers = new ArrayList<>();
        } else if (allUsers.contains(user)) {
            // already exists
            return false;
        }
        allUsers.add(user);
        if (db.saveLocalUsers(allUsers)) {
            // clear cache for reload
            localUsers.clear();
            return true;
        } else {
            return false;
        }
    }

    public boolean removeUser(ID user) {
        AccountDBI db = getDatabase();
        List<ID> allUsers = db.getLocalUsers();
        if (allUsers == null || !allUsers.contains(user)) {
            // not exists
            return false;
        }
        allUsers.remove(user);
        if (db.saveLocalUsers(allUsers)) {
            // clear cache for reload
            localUsers.clear();
            return true;
        } else {
            return false;
        }
    }

    @Override
    public void setCurrentUser(User user) {
        AccountDBI db = getDatabase();
        UserTable table = (UserTable) db;
        table.setCurrentUser(user.getIdentifier());
        // clear cache for reload
        localUsers.clear();
        super.setCurrentUser(user);
    }

    //-------- Contacts

    @Override
    public List<ID> getContacts(ID user) {
        List<ID> contacts = userContacts.get(user);
        if (contacts == null) {
            contacts = super.getContacts(user);
            if (contacts == null) {
                // placeholder
                contacts = new ArrayList<>();
            }
            userContacts.put(user, contacts);
        }
        return contacts;
    }

    public boolean saveContacts(List<ID> contacts, ID user) {
        AccountDBI db = getDatabase();
        if (db.saveContacts(contacts, user)) {
            // erase cache for reload
            userContacts.remove(user);
            return true;
        } else {
            return false;
        }
    }

    public boolean addContact(ID contact, ID user) {
        List<ID> allContacts = getContacts(user);
        int pos = allContacts.indexOf(contact);
        if (pos >= 0) {
            // already exists
            return false;
        }
        allContacts.add(contact);
        return saveContacts(allContacts, user);
    }

    public boolean removeContact(ID contact, ID user) {
        List<ID> allContacts = getContacts(user);
        int pos = allContacts.indexOf(contact);
        if (pos < 0) {
            // not exists
            return false;
        }
        allContacts.remove(pos);
        return saveContacts(allContacts, user);
    }

    //-------- Members

    //
    //  Address Name Service
    //
    public static AddressNameTable ansTable = null;

    static {
        ans = new AddressNameServer() {

            @Override
            public ID identifier(String name) {
                ID identifier = super.identifier(name);
                if (identifier != null) {
                    return identifier;
                }
                identifier = ansTable.getIdentifier(name);
                if (identifier != null) {
                    // FIXME: is reserved name?
                    cache(name, identifier);
                }
                return identifier;
            }

            @Override
            public boolean save(String name, ID identifier) {
                if (!cache(name, identifier)) {
                    return false;
                }
                if (identifier == null) {
                    return ansTable.removeRecord(name);
                } else {
                    return ansTable.addRecord(identifier, name);
                }
            }
        };
    }
}
