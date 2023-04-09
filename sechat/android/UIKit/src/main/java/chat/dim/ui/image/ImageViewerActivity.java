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

import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import androidx.core.widget.NestedScrollView;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import android.view.View;
import android.widget.ImageView;

import chat.dim.ui.OnDoubleClickListener;
import chat.dim.ui.R;

public class ImageViewerActivity extends AppCompatActivity {

    private NestedScrollView scrollView = null;

    private ImageView imageView = null;
    private Images.Size originSize = Images.Size.ZERO;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.imageviewer_activity);
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        scrollView = findViewById(R.id.scrollView);
        imageView = findViewById(R.id.imageView);

        imageView.setOnClickListener(new OnDoubleClickListener() {
            @Override
            protected void onDoubleClick(View v) {
                resizeImage();
            }
        });

        Intent intent = getIntent();
        if (intent != null) {
            Uri imageUri = intent.getParcelableExtra("URI");
            assert imageUri != null : "image URI not set";
            Bitmap bitmap = BitmapFactory.decodeFile(imageUri.getPath());
            if (bitmap != null) {
                originSize = new Images.Size(bitmap.getWidth(), bitmap.getHeight());
                imageView.setImageBitmap(bitmap);
                resizeImage();
            }

            String title = intent.getStringExtra("title");
            if (title != null) {
                setTitle(title);
            }
        }
    }

    private void resizeImage() {
        Images.Size size = new Images.Size(imageView.getWidth(), imageView.getHeight());
        if (size.width <= 0 || size.height <= 0) {
            // error
            return;
        }
        if (originSize.width == 0 && originSize.height == 0) {
            originSize = size;
            return;
        }
        if (size.width == originSize.width && size.height == originSize.height) {
            Images.Size maxSize = new Images.Size(scrollView.getMeasuredWidth(), scrollView.getMeasuredHeight());
            float x = ((float) maxSize.width) / size.width;
            float y = ((float) maxSize.height) / size.height;
            float ratio = Math.max(x, y);
            int w = Math.round(size.width * ratio);
            int h = Math.round(size.height * ratio);
            size = new Images.Size(w, h);
        } else {
            size = originSize;
        }
        imageView.setMaxWidth(size.width);
        imageView.setMaxHeight(size.height);
        imageView.setMinimumWidth(size.width);
        imageView.setMinimumHeight(size.height);
    }

    public static void show(Context context, Uri imageUri, String title) {
        Intent intent = new Intent();
        intent.setClass(context, ImageViewerActivity.class);
        intent.putExtra("URI", imageUri);
        intent.putExtra("title", title);
        context.startActivity(intent);
    }
}
