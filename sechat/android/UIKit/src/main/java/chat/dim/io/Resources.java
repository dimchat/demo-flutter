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

import android.content.ContentResolver;
import android.content.ContextWrapper;
import android.graphics.Bitmap;
import android.net.Uri;

import java.io.IOException;

import chat.dim.ui.image.Images;

public class Resources {

    public static Bitmap getBitmapFromMipmap(ContextWrapper wrapper, int resId) {
        Uri uri = getUriFromMipmap(wrapper.getResources(), resId);
        try {
            return Images.bitmapFormUri(uri, wrapper.getContentResolver());
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }

    }
    public static Uri getUriFromMipmap(android.content.res.Resources resources, int resId) {
        return Uri.parse(ContentResolver.SCHEME_ANDROID_RESOURCE + "://"
                + resources.getResourcePackageName(resId) + "/"
                + resources.getResourceTypeName(resId) + "/"
                + resources.getResourceEntryName(resId));
    }
}
