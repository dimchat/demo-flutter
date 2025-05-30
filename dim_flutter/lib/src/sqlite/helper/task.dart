/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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
 * =============================================================================
 */
import 'package:mutex/mutex.dart';

import 'package:dim_client/ok.dart';


///
///  Task for data access
///


abstract class DbTask<K, V> with Logging {
  DbTask(this.mutexLock, this.cachePool, {
    double? cacheExpires, double? cacheRefresh
  }) {
    _cacheExpires = cacheExpires ?? 3600;
    _cacheRefresh = cacheRefresh ?? 128;
    assert(_cacheExpires > 0, 'cache expires duration error: $_cacheExpires');
    assert(_cacheRefresh > 0, 'cache refresh duration error: $_cacheRefresh');
  }

  // protected
  final Mutex mutexLock;
  // memory cache
  final CachePool<K, V> cachePool;
  late final double _cacheExpires;  // in seconds
  late final double _cacheRefresh;  // in seconds

  /// key for memory cache
  K get cacheKey;

  // protected
  Future<V?> readData();

  // protected
  Future<bool> writeData(V value);

  /// Task Save
  Future<bool> save(V value) async {
    double now = Time.currentTimeSeconds;
    bool ok;
    await mutexLock.acquire();
    try {
      // save into local storage
      ok = await writeData(value);
      if (ok) {
        // update memory cache
        cachePool.updateValue(cacheKey, value, _cacheExpires, now: now);
      }
    } finally {
      mutexLock.release();
    }
    return ok;
  }

  /// Task Load
  Future<V?> load() async {
    double now = Time.currentTimeSeconds;
    CachePair<V>? pair;
    CacheHolder<V>? holder;
    V? value;
    ///
    ///  1. check memory cache
    ///
    pair = cachePool.fetch(cacheKey, now: now);
    holder = pair?.holder;
    value = pair?.value;
    if (value != null) {
      // got it from cache
      return value;
    } else if (holder == null) {
      // holder not exists, means it is the first querying
    } else if (holder.isAlive(now: now)) {
      // holder is not expired yet,
      // means the value is actually empty,
      // no need to check it again
      return null;
    }
    ///
    ///  2. lock for querying
    ///
    await mutexLock.acquire();
    try {
      // locked, check again to make sure the cache not exists.
      // (maybe the cache was updated by other threads while waiting the lock)
      pair = cachePool.fetch(cacheKey, now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value != null) {
        return value;
      } else if (holder == null) {
        // not load yet, wait to load
      } else if (holder.isAlive(now: now)) {
        // value not exists
        return null;
      } else {
        // cache expired, wait to reload
        holder.renewal(_cacheRefresh, now: now);
      }
      // load from local storage
      value = await readData();
      // update memory cache
      cachePool.updateValue(cacheKey, value, _cacheExpires, now: now);
    } finally {
      mutexLock.release();
    }
    ///
    ///  3. OK, return cached value
    ///
    return value;
  }

}


class DataCache<K, V> with Logging {
  DataCache(String poolName)
      : cachePool = CacheManager().getPool(poolName);

  final CachePool<K, V> cachePool;
  final Mutex mutexLock = Mutex();

}
