package chat.dim.sechat;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

import chat.dim.channels.ChannelManager;

public class MainActivity extends FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        System.out.println("initialize flutter channels");
        ChannelManager manager = ChannelManager.getInstance();
        manager.initChannels(flutterEngine.getDartExecutor().getBinaryMessenger());

        boolean ok = tryLaunch();
        if (ok) {
            System.out.println("app launch");
        } else {
            System.out.println("failed to launch app");
        }
        //assert ok : "error";
    }

    boolean tryLaunch() {
        try {
            return SechatApp.launch(getApplication(), this);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}
