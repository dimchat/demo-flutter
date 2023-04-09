package chat.dim;

import chat.dim.dbi.AccountDBI;
import chat.dim.dbi.MessageDBI;
import chat.dim.dbi.SessionDBI;

public enum GlobalVariable {

    INSTANCE;

    public static GlobalVariable getInstance() {
        return INSTANCE;
    }

    GlobalVariable() {
        SharedDatabase db = new SharedDatabase();
        adb = db;
        mdb = db;
        sdb = db;
        database = db;
        facebook = new SharedFacebook(db);
        emitter = new Emitter();

        CryptoPlugins.registerCryptoPlugins();

        Register.prepare();
    }

    public final AccountDBI adb;
    public final MessageDBI mdb;
    public final SessionDBI sdb;
    public final SharedDatabase database;

    public final SharedFacebook facebook;

    public final Emitter emitter;

    public SharedMessenger messenger = null;
    public Terminal terminal = null;
}
