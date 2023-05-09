package chat.dim;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

import chat.dim.channels.ChannelManager;
import chat.dim.filesys.LocalCache;
import chat.dim.http.UpdateManager;

public class MainActivity extends FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        String path = MainActivity.this.getExternalCacheDir().getAbsolutePath();
        System.out.println("cache root: " + path);
        LocalCache cache = LocalCache.getInstance();
        cache.setRoot(path);

        CryptoPlugins.registerCryptoPlugins();

        Register.prepare();

        System.out.println("initialize flutter channels");
        ChannelManager manager = ChannelManager.getInstance();
        manager.initChannels(flutterEngine.getDartExecutor().getBinaryMessenger());

    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        if (isApkInDebug(MainActivity.this)) {
            Log.w("INIT", "Application in DEBUG mode");
        } else {
            chat.dim.utils.Log.LEVEL = chat.dim.utils.Log.RELEASE;
            Log.w("INIT", "Application in RELEASE mode");
        }
        super.onCreate(savedInstanceState);

        UpdateManager manager = new UpdateManager(MainActivity.this);
        manager.checkUpdateInfo();
    }

    public static boolean isApkInDebug(Context context) {
        try {
            ApplicationInfo info = context.getApplicationInfo();
            return (info.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        } catch (Exception e) {
            Log.e("INIT", "failed to get debuggable");
            return false;
        }
    }

    static {

        chat.dim.utils.Log.LEVEL = chat.dim.utils.Log.DEBUG;
        Log.w("INIT", "set Log.LEVEL = DEBUG");

    }
}
