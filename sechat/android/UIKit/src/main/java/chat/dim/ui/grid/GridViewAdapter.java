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

import androidx.annotation.NonNull;
import androidx.core.os.TraceCompat;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;

import chat.dim.ui.list.DummyList;
import chat.dim.ui.list.Listener;

public abstract class GridViewAdapter<VH extends GridViewHolder, L extends DummyList> extends BaseAdapter {

    protected final L dummyList;
    protected final Listener listener;

    public GridViewAdapter(L list, Listener observer) {
        super();
        dummyList = list;
        listener = observer;
    }

    @Override
    public int getCount() {
        return dummyList.getCount();
    }

    @Override
    public Object getItem(int position) {
        return dummyList.getItem(position);
    }

    @Override
    public long getItemId(int position) {
        // TODO: override me
        return position;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        GridViewHolder holder = createViewHolder(parent);
        onBindViewHolder(holder, position);
        return holder.itemView;
    }

    @NonNull
    public final VH createViewHolder(@NonNull ViewGroup parent) {
        VH holder;
        try {
            TraceCompat.beginSection("RV CreateView");
            holder = onCreateViewHolder(parent);
            if (holder.itemView.getParent() != null) {
                throw new IllegalStateException("ViewHolder views must not be attached when created. " +
                        "Ensure that you are not passing 'true' to the attachToRoot parameter of LayoutInflater.inflate(..., boolean attachToRoot)");
            }
        } finally {
            TraceCompat.endSection();
        }
        return holder;
    }

    @NonNull
    public abstract VH onCreateViewHolder(@NonNull ViewGroup parent);
    public abstract void onBindViewHolder(@NonNull GridViewHolder holder, int position);
}
