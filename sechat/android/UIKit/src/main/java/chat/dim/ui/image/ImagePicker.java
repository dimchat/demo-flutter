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
package chat.dim.ui.image;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

import chat.dim.io.Permissions;
import chat.dim.io.Storage;
import chat.dim.ui.Alert;
import chat.dim.ui.R;

public class ImagePicker implements DialogInterface.OnClickListener {

    private static final String ACTION_IMAGE_CAPTURE = MediaStore.ACTION_IMAGE_CAPTURE; // "android.media.action.IMAGE_CAPTURE"
    private static final String EXTRA_OUTPUT = MediaStore.EXTRA_OUTPUT;

    private static final String ACTION_PICK = Intent.ACTION_PICK;                       // "android.intent.action.PICK"
    private static final String ACTION_CROP = "com.android.camera.action.CROP";

    private static final Uri EXTERNAL_CONTENT_URI = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
    private static final String TITLE = MediaStore.Images.Media.TITLE;
    private static final String DATA_TYPE = "image/*";
    private static final String OUTPUT_FORMAT = Bitmap.CompressFormat.JPEG.toString();

    public enum RequestCode {

        Album  (0x0201),
        Camera (0x0202),
        Crop   (0x0204);

        public final int value;

        RequestCode(int value) {
            this.value = value;
        }
    }

    private final Activity activity;

    public String crop = "true";
    public float aspectX = 1;
    public float aspectY = 1;
    public float outputX = 256;
    public float outputY = 256;
    public boolean scale = true;
    public boolean scaleUpIfNeeded = true;
    public boolean noFaceDetection = true;

    public ImagePicker(Activity activity) {
        super();
        this.activity = activity;
    }

    public void start() {
        if (!Permissions.canAccessCamera(activity)) {
            Permissions.requestCameraPermissions(activity);
            return;
        }
        CharSequence[] items = {
                activity.getText(R.string.camera),
                activity.getText(R.string.album),
        };
        Alert.alert(activity, items, this);
    }

    @Override
    public void onClick(DialogInterface dialog, int which) {
        switch (which) {
            case 0: {
                openCamera();
                break;
            }

            case 1: {
                openAlbum();
                break;
            }
        }
    }

    Uri captureUri = null;

    private void openCamera() {
        String filename = "photo-" + System.currentTimeMillis() + ".jpeg";
        ContentValues values = new ContentValues();
        values.put(TITLE, filename);

        ContentResolver resolver = activity.getContentResolver();

        Intent intent = new Intent(ACTION_IMAGE_CAPTURE);
        captureUri = resolver.insert(EXTERNAL_CONTENT_URI, values);
        intent.putExtra(EXTRA_OUTPUT, captureUri);
        activity.startActivityForResult(intent, RequestCode.Camera.value);
    }

    void openAlbum() {
        Intent intent = new Intent(ACTION_PICK);
        intent.setDataAndType(EXTERNAL_CONTENT_URI, DATA_TYPE);
        activity.startActivityForResult(intent, RequestCode.Album.value);
    }

    public Bitmap getBitmap(Intent data) {
        Bitmap bitmap;
        Bundle bundle = data.getExtras();
        if (bundle != null) {
            bitmap = bundle.getParcelable("data");
            if (bitmap != null) {
                return bitmap;
            }
        }
        Uri source = data.getData();
        if (source == null) {
            String action = data.getAction();
            if (action != null) {
                source = Uri.parse(action);
            }
        }
        return getBitmap(source);
    }
    public Bitmap getBitmap(Uri source) {
        if (source == null) {
            return null;
        }
        try {
            ContentResolver resolver = activity.getContentResolver();
            InputStream is = resolver.openInputStream(source);
            return BitmapFactory.decodeStream(is);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }
        return null;
    }

    public boolean cropPicture(Uri data, String tempDir) throws IOException {
        File file = Storage.createTempFile("picture", ".jpeg", tempDir);
        Uri output = Uri.fromFile(file);

        Intent intent = new Intent(ACTION_CROP);
        intent.setDataAndType(data, DATA_TYPE);

        intent.putExtra("crop", crop);
        intent.putExtra("aspectX", aspectX);
        intent.putExtra("aspectY", aspectY);
        intent.putExtra("outputX", outputX);
        intent.putExtra("outputY", outputY);
        intent.putExtra("scale", scale);
        intent.putExtra("scaleUpIfNeeded", scaleUpIfNeeded);
        intent.putExtra("noFaceDetection", noFaceDetection);

        intent.putExtra("return-data", false);
        intent.putExtra(EXTRA_OUTPUT, output);
        intent.putExtra("outputFormat", OUTPUT_FORMAT);

        if (intent.resolveActivity(activity.getPackageManager()) == null) {
            // CROP not support
            return false;
        }

        activity.startActivityForResult(intent, RequestCode.Crop.value);
        return true;
    }
}
