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
package chat.dim.threading;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

class TaskPool {

    private final List<Runnable> tasks = new ArrayList<>();
    private final ReadWriteLock taskLock = new ReentrantReadWriteLock();

    void addTask(Runnable runnable) {
        Lock writeLock = taskLock.writeLock();
        writeLock.lock();
        try {
            tasks.add(runnable);
        } finally {
            writeLock.unlock();
        }
    }

    Runnable getTask() {
        Runnable runnable;
        Lock writeLock = taskLock.writeLock();
        writeLock.lock();
        try {
            // NOTICE: take the last job
            int index = tasks.size() - 1;
            if (index < 0) {
                runnable = null;
            } else {
                runnable = tasks.remove(index);
            }
        } finally {
            writeLock.unlock();
        }
        return runnable;
    }
}
