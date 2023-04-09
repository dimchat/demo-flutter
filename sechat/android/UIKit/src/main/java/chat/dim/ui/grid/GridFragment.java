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
package chat.dim.ui.grid;

import androidx.fragment.app.Fragment;
import android.widget.GridView;

import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

import chat.dim.threading.MainThread;
import chat.dim.ui.list.DummyList;

public class GridFragment<VA extends GridViewAdapter, L extends DummyList> extends Fragment {

    private boolean isReloading = false;

    protected L dummyList = null;
    protected VA adapter = null;

    private final ReadWriteLock dummyLock = new ReentrantReadWriteLock();

    /**
     * Mandatory empty constructor for the fragment manager to instantiate the
     * fragment (e.g. upon screen orientation changes).
     */
    public GridFragment() {
        super();
    }

    protected void bindGridView(GridView view) {
        view.setAdapter(adapter);
    }

    public void reloadData() {
        Lock writeLock = dummyLock.readLock();
        writeLock.lock();
        try {
            if (!isReloading) {
                isReloading = true;
                dummyList.reloadData();
                MainThread.call(this::onReloaded);
            }
        } finally {
            isReloading = false;
            writeLock.unlock();
        }
    }
    protected void onReloaded() {
        adapter.notifyDataSetChanged();
    }
}
