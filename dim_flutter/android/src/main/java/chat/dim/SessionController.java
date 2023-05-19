package chat.dim;

import java.io.IOError;
import java.net.SocketAddress;
import java.util.ArrayList;
import java.util.List;

import chat.dim.channels.ChannelManager;
import chat.dim.channels.SessionChannel;
import chat.dim.dbi.SessionDBI;
import chat.dim.mkm.Station;
import chat.dim.network.ClientSession;
import chat.dim.network.CommonGate;
import chat.dim.network.SessionState;
import chat.dim.network.StateMachine;
import chat.dim.port.Arrival;
import chat.dim.port.Departure;
import chat.dim.port.Docker;
import chat.dim.protocol.ID;
import chat.dim.utils.Log;

public enum SessionController implements SessionState.Delegate, Docker.Delegate {

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
        // 0. check old session
        ClientSession cs = session;
        if (cs != null) {
            Station station = cs.getStation();
            String oHost = station.getHost();
            int oPort = station.getPort();
            if (oPort == port && host.equals(oHost)) {
                Log.info("checking connection state: " + station);
                SessionState state = cs.getState();
                if (state.equals(SessionState.Order.ERROR)) {
                    Log.error("current station is not connected: " + state);
                } else {
                    Log.warning("current station state: " + state);
                    return;
                }
            }
            Log.warning("close old session: " + cs);
            cs.stop();
            session = null;
        }
        Log.warning("connection to " + host + ":" + port);
        // 1. create station
        Station station = new Station(host, port);
        station.setDataSource(facebook);
        // 2. create session for station
        cs = new SharedSession(station, database);
        cs.start(this);
        session = cs;
    }

    public boolean login(ID user) {
        ClientSession cs = session;
        return cs != null && cs.setIdentifier(user);
    }

    public void setSessionKey(String sessionKey) {
        ClientSession cs = session;
        if (cs != null) {
            cs.setKey(sessionKey);
        }
    }

    public SessionState getState() {
        ClientSession cs = session;
        if (cs == null) {
            return null;
        }
        return cs.getState();
    }

    //
    //  SessionState Delegate
    //

    @Override
    public void enterState(SessionState next, StateMachine ctx, long now) {

    }

    @Override
    public void exitState(SessionState previous, StateMachine ctx, long now) {
        SessionState current = ctx.getCurrentState();
        Log.info("state changed: " + previous + " -> " + current);
        // check docker for current session
        if (current == null) {
            Log.warning("current state empty, stopped?");
        } else if (current.equals(SessionState.Order.CONNECTING)) {
            ClientSession cs = session;
            if (cs == null) {
                Log.error("client session gone");
            } else {
                CommonGate gate = cs.getGate();
                if (gate == null) {
                    Log.error("failed to open gate: " + cs.getStation());
                } else {
                    SocketAddress remote = cs.getRemoteAddress();
                    Docker docker = gate.getDocker(remote, null, new ArrayList<>());
                    if (docker == null) {
                        Log.error("failed to create docker: " + remote);
                    } else {
                        Log.info("created docker: " + docker);
                    }
                }
            }
        }
        // callback for flutter
        ChannelManager manager = ChannelManager.getInstance();
        SessionChannel channel = manager.sessionChannel;
        channel.onStateChanged(previous, current, now);
    }

    @Override
    public void pauseState(SessionState current, StateMachine ctx, long now) {

    }

    @Override
    public void resumeState(SessionState current, StateMachine ctx, long now) {

    }

    //
    //  Docker Delegate
    //

    @Override
    public void onDockerReceived(Arrival arrival, Docker docker) {
        // get data packages from arrival ship's payload
        SocketAddress remote = docker.getRemoteAddress();
        List<byte[]> packages = ClientSession.getDataPackages(arrival);
        ChannelManager manager = ChannelManager.getInstance();
        SessionChannel channel = manager.sessionChannel;
        for (byte[] pack : packages) {
            Log.info("pack length: " + pack.length);
            channel.onReceived(pack, remote);
        }
    }

    @Override
    public void onDockerSent(Departure departure, Docker docker) {

    }

    @Override
    public void onDockerFailed(IOError error, Departure departure, Docker docker) {

    }

    @Override
    public void onDockerError(IOError error, Departure departure, Docker docker) {

    }

    @Override
    public void onDockerStatusChanged(Docker.Status previous, Docker.Status current, Docker docker) {

    }
}
