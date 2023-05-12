package chat.dim.channels;

import android.app.Activity;
import android.content.ContextWrapper;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

import chat.dim.filesys.ExternalStorage;
import chat.dim.filesys.LocalCache;
import chat.dim.filesys.Paths;
import chat.dim.ui.media.AudioPlayer;
import chat.dim.ui.media.AudioRecorder;
import chat.dim.utils.Log;

public class AudioChannel extends MethodChannel {

    private AudioPlayer audioPlayer = null;
    private AudioRecorder audioRecorder = null;

    public AudioChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
        super(messenger, name, codec);
        setMethodCallHandler(new AudioChannelHandler());
    }

    public void initAudioPlayer(ContextWrapper context) {
        audioPlayer = new AudioPlayer(context);
    }
    public void initAudioRecorder(Activity activity) {
        audioRecorder = new AudioRecorder(activity);
    }

    public void onRecordFinished(String mp4Path, float seconds) {
        byte[] data;
        try {
            data = ExternalStorage.loadBinary(mp4Path);
        } catch (IOException e) {
            e.printStackTrace();
            return;
        }
        Map<String, Object> params = new HashMap<>();
        params.put("data", data);
        params.put("current", seconds);
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_RECORD_FINISHED, params));
    }

    public void onPlayFinished(String mp4Path) {
        Map<String, Object> params = new HashMap<>();
        params.put("mp4Path", mp4Path);
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_PLAY_FINISHED, params));
    }

    static class AudioChannelHandler implements MethodChannel.MethodCallHandler {

        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
            String method = call.method;
            switch (method) {
                case ChannelMethods.START_RECORD: {
                    startRecord();
                    break;
                }
                case ChannelMethods.STOP_RECORD: {
                    stopRecord();
                    break;
                }
                case ChannelMethods.START_PLAY: {
                    String path = call.argument("path");
                    startPlay(path);
                    break;
                }
                case ChannelMethods.STOP_PLAY: {
                    stopPlay();
                    break;
                }
            }
        }

        private void startRecord() {
            String dir = LocalCache.getInstance().getTemporaryDirectory();
            String path = Paths.append(dir, "voice.mp4");
            ChannelManager man = ChannelManager.getInstance();
            man.audioChannel.audioRecorder.startRecord(path);
        }

        private void stopRecord() {
            ChannelManager man = ChannelManager.getInstance();
            AudioRecorder recorder = man.audioChannel.audioRecorder;
            String path = recorder.stopRecord();
            if (path == null || !Paths.exists(path)) {
                Log.error("voice file not found: " + path);
                return;
            }
            man.audioChannel.onRecordFinished(path, recorder.getDuration());
        }

        private void startPlay(String path) {
            Uri url = Uri.fromFile(new File(path));
            ChannelManager man = ChannelManager.getInstance();
            man.audioChannel.audioPlayer.startPlay(url);
        }

        private void stopPlay() {
            ChannelManager man = ChannelManager.getInstance();
            man.audioChannel.audioPlayer.stopPlay();
        }
    }
}
