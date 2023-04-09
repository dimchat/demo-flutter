/* license: https://mit-license.org
 * ==============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2020 Albert Moky
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
package chat.dim.io;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.util.ArrayList;
import java.util.List;

public class Permissions {

    public enum RequestCode {

        ExternalStorage (0x0101),
        Camera          (0x0102),
        Microphone      (0x0104);

        public final int value;

        RequestCode(int value) {
            this.value = value;
        }
    }

    private static final int PERMISSION_GRANTED = PackageManager.PERMISSION_GRANTED;

    private static boolean isGranted(Context context, String permission) {
        return PERMISSION_GRANTED == ContextCompat.checkSelfPermission(context, permission);
    }

    private static void requestPermissions(Activity activity, String[] permissions, int requestCode) {
        List<String> requests = new ArrayList<>();
        for (String item : permissions) {
            if (isGranted(activity, item)) {
                // granted
                continue;
            }
            requests.add(item);
        }
        permissions = requests.toArray(new String[0]);
        if (permissions.length == 0) {
            // all permissions granted
            return;
        }
        ActivityCompat.requestPermissions(activity, permissions, requestCode);
    }

    //
    //  External Storage
    //

    private static final String READ_EXTERNAL_STORAGE = Manifest.permission.READ_EXTERNAL_STORAGE;
    private static final String WRITE_EXTERNAL_STORAGE = Manifest.permission.WRITE_EXTERNAL_STORAGE;
    private static final String[] EXTERNAL_STORAGE_PERMISSIONS = {
            READ_EXTERNAL_STORAGE,
            WRITE_EXTERNAL_STORAGE
    };

    public static boolean canWriteExternalStorage(Context activity) {
        return isGranted(activity, WRITE_EXTERNAL_STORAGE);
    }

    public static void requestExternalStoragePermissions(Activity activity) {
        requestPermissions(activity, EXTERNAL_STORAGE_PERMISSIONS, RequestCode.ExternalStorage.value);
    }

    //
    //  Camera
    //

    private static final String CAMERA = Manifest.permission.CAMERA;
    private static final String[] CAMERA_PERMISSIONS = {
            READ_EXTERNAL_STORAGE,
            WRITE_EXTERNAL_STORAGE,
            CAMERA
    };

    public static boolean canAccessCamera(Context context) {
        return isGranted(context, CAMERA);
    }

    public static void requestCameraPermissions(Activity activity) {
        requestPermissions(activity, CAMERA_PERMISSIONS, RequestCode.Camera.value);
    }

    //
    //  Microphone
    //

    private static final String RECORD_AUDIO = Manifest.permission.RECORD_AUDIO;
    private static final String[] MICROPHONE_PERMISSIONS = {
            READ_EXTERNAL_STORAGE,
            WRITE_EXTERNAL_STORAGE,
            RECORD_AUDIO
    };

    public static boolean canAccessMicrophone(Context activity) {
        return isGranted(activity, RECORD_AUDIO);
    }

    public static void requestMicrophonePermissions(Activity activity) {
        requestPermissions(activity, MICROPHONE_PERMISSIONS, RequestCode.Microphone.value);
    }
}
