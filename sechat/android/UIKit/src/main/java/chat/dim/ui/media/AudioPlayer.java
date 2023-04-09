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

import android.content.ComponentName;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.ServiceConnection;
import android.net.Uri;
import android.os.IBinder;

public class AudioPlayer {

    private final ContextWrapper activity;

    private MediaService.Binder binder = null;
    private final Connection connection = new Connection();

    public AudioPlayer(ContextWrapper activity) {
        super();
        this.activity = activity;
    }

    public void startPlay(Uri inputUri) {
        Intent intent = new Intent(activity, MediaService.class);
        intent.setAction(MediaService.PLAY);
        intent.setData(inputUri);
        activity.startService(intent);
        activity.bindService(intent, connection, Context.BIND_AUTO_CREATE);
    }

    public void stopPlay() {
        if (binder != null) {
            binder.stopPlay();
            activity.unbindService(connection);
        }
        activity.stopService(new Intent(activity, MediaService.class));
    }

    /**
     *  Get playing duration
     *
     * @return seconds
     */
    public float getDuration() {
        if (binder == null) {
            return -1;
        }
        return binder.getPlayDuration() / 1000.0f;
    }

    private class Connection implements ServiceConnection {

        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            binder = (MediaService.Binder) service;
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            binder = null;
        }
    }
}
