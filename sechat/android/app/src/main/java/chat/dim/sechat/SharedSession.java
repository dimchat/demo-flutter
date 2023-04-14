package chat.dim.sechat;

import java.io.IOError;

import chat.dim.dbi.SessionDBI;
import chat.dim.mkm.Station;
import chat.dim.network.ClientSession;
import chat.dim.port.Arrival;
import chat.dim.port.Departure;
import chat.dim.port.Docker;

class SharedSession extends ClientSession {
    public SharedSession(Station server, SessionDBI sdb) {
        super(server, sdb);
    }

    @Override
    public void onDockerSent(Departure ship, Docker docker) {
        //super.onDockerSent(ship, docker);
        SessionController controller = SessionController.getInstance();
        controller.onDockerSent(ship, docker);
    }

    @Override
    public void onDockerReceived(Arrival ship, Docker docker) {
        //super.onDockerReceived(ship, docker);
        SessionController controller = SessionController.getInstance();
        controller.onDockerReceived(ship, docker);
    }

    @Override
    public void onDockerFailed(IOError error, Departure departure, Docker docker) {
        super.onDockerFailed(error, departure, docker);
        SessionController controller = SessionController.getInstance();
        controller.onDockerFailed(error, departure, docker);
    }

    @Override
    public void onDockerError(IOError error, Departure departure, Docker docker) {
        super.onDockerError(error, departure, docker);
        SessionController controller = SessionController.getInstance();
        controller.onDockerError(error, departure, docker);
    }

    @Override
    public void onDockerStatusChanged(Docker.Status previous, Docker.Status current, Docker docker) {
        super.onDockerStatusChanged(previous, current, docker);
        SessionController controller = SessionController.getInstance();
        controller.onDockerStatusChanged(previous, current, docker);
    }
}
