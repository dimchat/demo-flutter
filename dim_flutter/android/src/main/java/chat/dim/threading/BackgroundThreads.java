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

public final class BackgroundThreads {

    //
    //  Tasks
    //

    private static final TaskPool rushing = new TaskPool();
    private static final TaskPool waiting = new TaskPool();

    public static void wait(Runnable runnable) {
        waiting.addTask(runnable);
    }
    public static void rush(Runnable runnable) {
        rushing.addTask(runnable);
    }

    //
    //  Thread pool
    //

    private static final TaskThread thread1 = new TaskThread.Urgency(rushing);
    private static final TaskThread thread2 = new TaskThread.Trivial(rushing, waiting);
    private static final TaskThread thread3 = new TaskThread.Trivial(rushing, waiting);

    public static void stop() {
        thread1.running = false;
        thread2.running = false;
        thread3.running = false;
    }

    static {
        thread1.start();
        thread2.start();
        thread3.start();
    }
}
