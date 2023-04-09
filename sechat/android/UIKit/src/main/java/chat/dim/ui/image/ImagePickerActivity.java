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

import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import java.io.IOException;

public abstract class ImagePickerActivity extends AppCompatActivity {

    private final ImagePicker imagePicker;

    public ImagePickerActivity() {
        super();
        imagePicker = new ImagePicker(this);
    }

    public void startImagePicker() {
        imagePicker.start();
    }

    protected void setCrop(boolean needsCrop) {
        if (needsCrop) {
            imagePicker.crop = "true";
        } else {
            imagePicker.crop = "false";
        }
    }

    protected abstract String getTemporaryDirectory() throws IOException;

    protected abstract void fetchImage(Bitmap bitmap);

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (requestCode == ImagePicker.RequestCode.Camera.value) {
            Uri source;
            if (data == null) {
                source = imagePicker.captureUri;
            } else {
                source = data.getData();
            }
            if (source == null) {
                // should not happen
                imagePicker.openAlbum();
                return;
            }
            if (imagePicker.crop != null && imagePicker.crop.equals("true")) {
                try {
                    if (imagePicker.cropPicture(source, getTemporaryDirectory())) {
                        // waiting for crop
                        return;
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                    return;
                }
            }
            // fetch image without crop
            fetchImage(imagePicker.getBitmap(source));
        } else if (requestCode == ImagePicker.RequestCode.Album.value) {
            if (data == null) {
                // cancelled
                return;
            }
            if (imagePicker.crop != null && imagePicker.crop.equals("true")) {
                // crop selected picture
                Uri source = data.getData();
                if (source == null) {
                    // no data
                    return;
                }
                try {
                    if (imagePicker.cropPicture(source, getTemporaryDirectory())) {
                        // waiting for crop
                        return;
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                    return;
                }
            }
            // fetch image without crop
            fetchImage(imagePicker.getBitmap(data));
            return;
        } else if (requestCode == ImagePicker.RequestCode.Crop.value) {
            if (data == null) {
                // cancelled
                return;
            }
            // fetch image after cropped
            fetchImage(imagePicker.getBitmap(data));
            return;
        }
        super.onActivityResult(requestCode, resultCode, data);
    }
}
