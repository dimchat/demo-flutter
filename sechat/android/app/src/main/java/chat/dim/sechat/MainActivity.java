package chat.dim.sechat;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

import chat.dim.CryptoPlugins;
import chat.dim.Register;
import chat.dim.channels.ChannelManager;

public class MainActivity extends FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        CryptoPlugins.registerCryptoPlugins();

        Register.prepare();

        System.out.println("initialize flutter channels");
        ChannelManager manager = ChannelManager.getInstance();
        manager.initChannels(flutterEngine.getDartExecutor().getBinaryMessenger());

    }
}
