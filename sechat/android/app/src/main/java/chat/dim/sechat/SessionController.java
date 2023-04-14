package chat.dim.sechat;

import chat.dim.CommonFacebook;
import chat.dim.channels.ChannelManager;
import chat.dim.channels.SessionChannel;
import chat.dim.dbi.SessionDBI;
import chat.dim.mkm.Station;
import chat.dim.network.ClientSession;
import chat.dim.network.SessionState;
import chat.dim.network.StateMachine;
import chat.dim.protocol.ID;
import chat.dim.utils.Log;

public enum SessionController implements SessionState.Delegate {

    INSTANCE;

    public static SessionController getInstance() {
        return INSTANCE;
    }

    SessionController() {

    }

    public SessionDBI database = null;
    public CommonFacebook facebook = null;

    public ClientSession session = null;

    public void connect(String host, int port) {
        SessionController controller = this;
        // 1. create station
        Station station = new Station(host, port);
        station.setDataSource(facebook);
        // 2. create session for station
        ClientSession cs = new ClientSession(station, database);
        cs.start(controller);
        session = cs;
    }

    public boolean login(ID user) {
        ClientSession cs = session;
        return cs != null && cs.setIdentifier(user);
    }

    public SessionState getState() {
        ClientSession cs = session;
        if (cs == null) {
            return null;
        }
        return cs.getState();
    }

    @Override
    public void enterState(SessionState next, StateMachine ctx, long now) {

    }

    @Override
    public void exitState(SessionState previous, StateMachine ctx, long now) {
        SessionState current = ctx.getCurrentState();
        Log.info("state changed: " + previous + " -> " + current);
        ChannelManager manager = ChannelManager.getInstance();
        SessionChannel channel = manager.sessionChannel;
        channel.onStateChanged(previous, current);
    }

    @Override
    public void pauseState(SessionState current, StateMachine ctx, long now) {

    }

    @Override
    public void resumeState(SessionState current, StateMachine ctx, long now) {

    }
}
