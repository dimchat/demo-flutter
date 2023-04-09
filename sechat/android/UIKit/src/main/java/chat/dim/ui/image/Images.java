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

import android.content.ContentResolver;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.net.Uri;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;

public class Images {

    public static class Size {

        public final int width;
        public final int height;

        public Size(int width, int height) {
            super();
            this.width = width;
            this.height = height;
        }

        public static final Size ZERO = new Size(0, 0);
    }

    public static Size getSize(Bitmap bitmap) {
        return new Size(bitmap.getWidth(), bitmap.getHeight());
    }

    //
    //  Scale
    //

    public static Bitmap scale(Bitmap origin, Size size) {
        if (origin == null) {
            return null;
        }
        int w = origin.getWidth();
        int h = origin.getHeight();
        if (w <= 0 || h <= 0) {
            return null;
        }
        float scaleX = ((float) size.width) / w;
        float scaleY = ((float) size.height) / h;
        Matrix matrix = new Matrix();
        matrix.postScale(scaleX, scaleY);
        return Bitmap.createBitmap(origin, 0, 0, w, h, matrix, false);
    }

    public static byte[] thumbnail(Bitmap big) {
        Size size = getSize(big);
        if (size.width <= MAX_SIZE.width && size.height <= MAX_SIZE.height) {
            // too small, no need to thumbnail
            return compress(big, Bitmap.CompressFormat.JPEG, JPEG_THUMBNAIL_QUALITY);
        }
        size = aspectFit(size, MAX_SIZE);
        Bitmap small = scale(big, size);
        return compress(small, Bitmap.CompressFormat.JPEG, JPEG_THUMBNAIL_QUALITY);
    }

    public static Size aspectFit(Size size, Size boxSize) {
        float x = ((float) boxSize.width) / size.width;
        float y = ((float) boxSize.height) / size.height;
        float ratio = Math.min(x, y);
        int w = Math.round(size.width * ratio);
        int h = Math.round(size.height * ratio);
        return new Size(w, h);
    }

    private static final Size MAX_SIZE = new Size(128, 128);

    private static final int PNG_IMAGE_QUALITY = 100;
    private static final int JPEG_PHOTO_QUALITY = 50;
    private static final int JPEG_THUMBNAIL_QUALITY = 0;

    //
    //  Load
    //

    public static Bitmap bitmapFromPath(String path) throws IOException {
        return bitmapFormUri(Uri.parse(path), null, null);
    }
    public static Bitmap bitmapFromPath(String path, Size size) throws IOException {
        return bitmapFormUri(Uri.parse(path), null, size);
    }
    public static Bitmap bitmapFormUri(Uri uri, ContentResolver contentResolver) throws IOException {
        return bitmapFormUri(uri, contentResolver, null);
    }
    public static Bitmap bitmapFormUri(Uri uri, ContentResolver contentResolver, Size size) throws IOException {
        // decode for bounds
        BitmapFactory.Options onlyBoundsOptions = new BitmapFactory.Options();
        onlyBoundsOptions.inJustDecodeBounds = true;
        onlyBoundsOptions.inDither = true;
        onlyBoundsOptions.inPreferredConfig = Bitmap.Config.ARGB_8888;
        decodeUri(contentResolver, uri, onlyBoundsOptions);

        // check for scale
        int inSampleSize;
        if (size == null || size.width == 0 || size.height == 0) {
            inSampleSize = 1;
        } else {
            int width = onlyBoundsOptions.outWidth;
            int height = onlyBoundsOptions.outHeight;
            if (width <= 0 || height <= 0) {
                return null;
            }
            int dx = width / size.width;
            int dy = height / size.height;
            inSampleSize = Math.max(dx, dy);
        }

        // decode for bitmap
        BitmapFactory.Options bitmapOptions = new BitmapFactory.Options();
        bitmapOptions.inSampleSize = inSampleSize;
        bitmapOptions.inDither = true;
        bitmapOptions.inPreferredConfig = Bitmap.Config.ARGB_8888;
        return decodeUri(contentResolver, uri, bitmapOptions);
    }
    private static Bitmap decodeUri(ContentResolver contentResolver, Uri uri, BitmapFactory.Options bitmapOptions) throws IOException {
        Bitmap bitmap;
        String scheme = uri.getScheme();
        if (scheme == null) {
            try (InputStream input = new FileInputStream(new File(uri.toString()))) {
                bitmap = BitmapFactory.decodeStream(input, null, bitmapOptions);
            }
        } else {
            try (InputStream input = contentResolver.openInputStream(uri)) {
                bitmap = BitmapFactory.decodeStream(input, null, bitmapOptions);
            }
        }
        return bitmap;
    }

    //
    //  Compress
    //

    public static byte[] jpeg(Bitmap bitmap) {
        return compress(bitmap, Bitmap.CompressFormat.JPEG, JPEG_PHOTO_QUALITY);
    }
    public static byte[] png(Bitmap bitmap) {
        return compress(bitmap, Bitmap.CompressFormat.PNG, PNG_IMAGE_QUALITY);
    }
    private static byte[] compress(Bitmap bitmap, Bitmap.CompressFormat format, int quality) {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        bitmap.compress(format, quality, outputStream);
        return outputStream.toByteArray();
    }

    //
    //  Merge
    //

    public static Bitmap tiles(List<Bitmap> bitmaps) {
        Bitmap first = bitmaps.get(0);
        Size size = getSize(first);
        return tiles(bitmaps, size.width, size.height, first.getConfig());
    }
    public static Bitmap tiles(List<Bitmap> bitmaps, Size size) {
        if (bitmaps.size() == 0) {
            return null;
        }
        Bitmap first = bitmaps.get(0);
        return tiles(bitmaps, size.width, size.height, first.getConfig());
    }
    private static Bitmap tiles(List<Bitmap> tiles, int width, int height, Bitmap.Config config) {
        Bitmap bitmap = Bitmap.createBitmap(width, height, config);
        Canvas canvas = new Canvas(bitmap);

        int count = tiles.size();
        assert count > 0 : "tiles should not be empty";

        // calculate size of small image
        int w, h;
        if (count == 1) {
            w = width / 2;
            h = height / 2;
        } else if (count <= 4) {
            w = (width - GAPS * 4) / 2;
            h = (height - GAPS * 4) / 2;
        } else {
            w = (width - GAPS * 6) / 3;
            h = (height - GAPS * 6) / 3;
        }

        // calculate origin point of small image
        switch (count) {
            case 1: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -1, -1, +0, +0); // center
                break;
            }
            case 2: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -2, -1, -1, +0); // left
                drawBitmap(canvas, tiles, 1, width, height, w, h, +0, -1, +1, +0); // right
                break;
            }
            case 3: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -1, -2, +0, -1); // top

                drawBitmap(canvas, tiles, 1, width, height, w, h, -2, +0, -1, +1); // bottom left
                drawBitmap(canvas, tiles, 2, width, height, w, h, +0, +0, +1, +1); // bottom right
                break;
            }
            case 4: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -2, -2, -1, -1); // top left
                drawBitmap(canvas, tiles, 1, width, height, w, h, +0, -2, +1, -1); // top right

                drawBitmap(canvas, tiles, 2, width, height, w, h, -2, +0, -1, +1); // bottom left
                drawBitmap(canvas, tiles, 3, width, height, w, h, +0, +0, +1, +1);  // bottom right
                break;
            }
            case 5: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -2, -2, -1, -1); // top left
                drawBitmap(canvas, tiles, 1, width, height, w, h, +0, -2, +1, -1); // top right

                drawBitmap(canvas, tiles, 2, width, height, w, h, -3, +0, -2, +1); // bottom left
                drawBitmap(canvas, tiles, 3, width, height, w, h, -1, +0, 0, +1);  // bottom center
                drawBitmap(canvas, tiles, 4, width, height, w, h, +1, +0, +2, +1); // bottom right
                break;
            }
            case 6: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -3, -2, -2, -1); // top left
                drawBitmap(canvas, tiles, 1, width, height, w, h, -1, -2, +0, -1); // top center
                drawBitmap(canvas, tiles, 2, width, height, w, h, +1, -2, +2, -1); // top right

                drawBitmap(canvas, tiles, 3, width, height, w, h, -3, +0, -2, +1); // bottom left
                drawBitmap(canvas, tiles, 4, width, height, w, h, -1, +0, +0, +1); // bottom center
                drawBitmap(canvas, tiles, 5, width, height, w, h, +1, +0, +2, +1); // bottom right
                break;
            }
            case 7: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -2, -3, -1, -2); // top left
                drawBitmap(canvas, tiles, 1, width, height, w, h, +0, -3, +1, -2); // top right

                drawBitmap(canvas, tiles, 2, width, height, w, h, -3, -1, -2, 0);  // middle left
                drawBitmap(canvas, tiles, 3, width, height, w, h, -1, -1, 0, 0);   // middle center
                drawBitmap(canvas, tiles, 4, width, height, w, h, +1, -1, +2, 0);  // middle right

                drawBitmap(canvas, tiles, 5, width, height, w, h, -2, +1, -1, +2); // bottom left
                drawBitmap(canvas, tiles, 6, width, height, w, h, +0, +1, +1, +2); // bottom right
                break;
            }
            case 8: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -3, -3, -2, -2); // top left
                drawBitmap(canvas, tiles, 1, width, height, w, h, -1, -3, 0, -2);  // top center
                drawBitmap(canvas, tiles, 2, width, height, w, h, +1, -3, +2, -2); // top right

                drawBitmap(canvas, tiles, 3, width, height, w, h, -2, -1, -1, 0);  // middle left
                drawBitmap(canvas, tiles, 4, width, height, w, h, +0, -1, +1, 0);  // middle right

                drawBitmap(canvas, tiles, 5, width, height, w, h, -3, +1, -2, +2); // bottom left
                drawBitmap(canvas, tiles, 6, width, height, w, h, -1, +1, 0, +2);  // bottom center
                drawBitmap(canvas, tiles, 7, width, height, w, h, +1, +1, +2, +2); // bottom right
                break;
            }
            default: {
                drawBitmap(canvas, tiles, 0, width, height, w, h, -3, -3, -2, -2); // top left
                drawBitmap(canvas, tiles, 1, width, height, w, h, -1, -3, 0, -2);  // top center
                drawBitmap(canvas, tiles, 2, width, height, w, h, +1, -3, +2, -2); // top right

                drawBitmap(canvas, tiles, 3, width, height, w, h, -3, -1, -2, 0);  // middle left
                drawBitmap(canvas, tiles, 4, width, height, w, h, -1, -1, 0, 0);   // middle center
                drawBitmap(canvas, tiles, 5, width, height, w, h, +1, -1, +2, 0);  // middle right

                drawBitmap(canvas, tiles, 6, width, height, w, h, -3, +1, -2, +2); // bottom left
                drawBitmap(canvas, tiles, 7, width, height, w, h, -1, +1, 0, +2);  // bottom center
                drawBitmap(canvas, tiles, 8, width, height, w, h, +1, +1, +2, +2); // bottom right
                break;
            }
        }

        return bitmap;
    }

    private static void drawBitmap(Canvas canvas, List<Bitmap> tiles, int index, int width, int height,
                                   int w, int h,
                                   int dx, int dy,
                                   int gx, int gy) {

        int x = width / 2 + w * dx / 2 + GAPS * gx;
        int y = height / 2 + h * dy / 2 + GAPS * gy;

        Rect rect = new Rect(x, y, x + w, y + h);
        canvas.drawBitmap(tiles.get(index), null, rect, null);
    }

    private static final int GAPS = 1;
}
