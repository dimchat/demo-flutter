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
package chat.dim.ui.media;

import android.app.Service;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.IBinder;

import java.io.IOException;

import chat.dim.ui.Alert;

public class MediaService extends Service {

    public static final String RECORD = "record";
    public static final String PLAY = "play";

    private MediaPlayer player = null;
    private MediaRecorder recorder = null;

    private String tempFile = null;
    private long recordStart = 0;
    private long recordStop = 0;

    public MediaService() {
        super();
    }

    @Override
    public IBinder onBind(Intent intent) {
        // Return the communication channel to the service.
        return new Binder();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent.getAction();
        Uri uri = intent.getData();
        if (action != null && uri != null) {
            if (action.equals(RECORD)) {
                startRecording(uri.getPath());
            } else if (action.equals(PLAY)) {
                startPlaying(uri);
            }
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        stopAll();
        super.onDestroy();
    }

    private void stopAll() {
        stopRecording();
        stopPlaying();
    }

    //
    //  Record
    //

    private void startRecording(String outputFile) {
        stopAll();

        recorder = new MediaRecorder();
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        recorder.setAudioChannels(1);
        recorder.setAudioSamplingRate(44100);    // fits all android
        recorder.setAudioEncodingBitRate(96000);

        recorder.setOutputFile(outputFile);
        try {
            recorder.prepare();
            recorder.start();
        } catch (IOException e) {
            e.printStackTrace();
        }

        tempFile = outputFile;
        recordStart = recordStop = System.currentTimeMillis();
    }

    private String stopRecording() {
        if (recorder != null) {
            try {
                recorder.stop();
            } catch (Exception e) {
                Alert.tips(getApplicationContext(), e.toString());
            }
            recorder.reset();
            recorder.release();
            recorder = null;
            recordStop = System.currentTimeMillis();
        }
        return tempFile;
    }

    private int getRecordedDuration() {
        return (int) (recordStop - recordStart);
    }

    //
    //  Playback
    //

    private void startPlaying(Uri inputUri) {
        stopAll();

        player = new MediaPlayer();
        player.setAudioStreamType(AudioManager.STREAM_MUSIC);
        player.setOnPreparedListener(MediaPlayer::start);
        try {
            player.setDataSource(getApplicationContext(), inputUri);
        } catch (IOException e) {
            e.printStackTrace();
        }
        player.prepareAsync();
    }

    private void stopPlaying() {
        if (player != null) {
            player.stop();
            player.reset();
            player.release();
            player = null;
        }
    }

    private int getPlayingDuration() {
        if (player == null) {
            return -1;
        }
        return player.getDuration();
    }

    //
    //  Binder: the communication channel to the service
    //

    class Binder extends android.os.Binder {

        void startRecord(String outputFile) {
            startRecording(outputFile);
        }

        String stopRecord() {
            return stopRecording();
        }

        int getRecordDuration() {
            return getRecordedDuration();
        }

        void startPlay(Uri inputUri) {
            startPlaying(inputUri);
        }

        void stopPlay() {
            stopPlaying();
        }

        /**
         *  Get duration from player
         *
         * @return the duration in milliseconds
         */
        int getPlayDuration() {
            return getPlayingDuration();
        }
    }
}
