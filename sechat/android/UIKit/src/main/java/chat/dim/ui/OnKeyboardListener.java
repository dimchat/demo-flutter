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
package chat.dim.ui;

import android.graphics.Rect;
import android.view.View;
import android.view.ViewTreeObserver;

public interface OnKeyboardListener {

    void onKeyboardShown();

    void onKeyboardHidden();
}

class SoftKeyboardListener {

    private static final int MIN_HEIGHT = 200;

    private View rootView;
    private int visibleHeight;
    private ViewTreeObserver.OnGlobalLayoutListener victim;
    private OnKeyboardListener listener;

    SoftKeyboardListener() {
        rootView = null;
        visibleHeight = 0;
        victim = null;
        listener = null;
    }

    void setListener(OnKeyboardListener listener) {
        this.listener = listener;
    }

    void setRootView(View view) {
        ViewTreeObserver observer;
        if (rootView != null && victim != null) {
            observer = rootView.getViewTreeObserver();
            observer.removeOnGlobalLayoutListener(victim);
        }
        rootView = view;
        if (rootView != null) {
            victim = () -> {
                Rect frame = new Rect();
                rootView.getWindowVisibleDisplayFrame(frame);
                int height = frame.height();
                if (visibleHeight > 0 && listener != null) {
                    if (visibleHeight - height > MIN_HEIGHT) {
                        listener.onKeyboardShown();
                    } else if (height - visibleHeight > MIN_HEIGHT) {
                        listener.onKeyboardHidden();
                    }
                }
                visibleHeight = height;
            };
            observer = rootView.getViewTreeObserver();
            observer.addOnGlobalLayoutListener(victim);
        }
    }
}
