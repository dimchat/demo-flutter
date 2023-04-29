/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
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

///
///  Weak Value Map
///

class WeakValueMap<K, V> implements Map<K, V> {
  WeakValueMap() : _inner = {};

  final Map<K, WeakReference<dynamic>?> _inner;

  Map<K, V> toMap() {
    // remove empty entry
    _inner.removeWhere((key, wr) => wr?.target == null);
    // convert
    return _inner.map((key, wr) => MapEntry(key, wr?.target));
  }

  @override
  V? operator [](Object? key) => _inner[key]?.target;

  @override
  void operator []=(K key, V value) =>
      _inner[key] = value == null ? null : WeakReference(value);

  @override
  void addAll(Map<K, V> other) => other.forEach((key, value) {
    this[key] = value;
  });

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    for (var entry in newEntries) {
      this[entry.key] = entry.value;
    }
  }

  @override
  Map<RK, RV> cast<RK, RV>() => toMap().cast();

  @override
  void clear() => _inner.clear();

  @override
  bool containsKey(Object? key) => toMap().containsKey(key);

  @override
  bool containsValue(Object? value) => toMap().containsValue(value);

  @override
  Iterable<MapEntry<K, V>> get entries => toMap().entries;

  @override
  void forEach(void Function(K key, V value) action) => _inner.forEach((key, wr) {
    V val = wr?.target;
    if (val != null) {
      action(key, val);
    }
  });

  @override
  bool get isEmpty => toMap().isEmpty;

  @override
  bool get isNotEmpty => toMap().isNotEmpty;

  @override
  Iterable<K> get keys => toMap().keys;

  @override
  int get length => toMap().length;

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) =>
      toMap().map(convert);

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    WeakReference<dynamic>? wr = _inner[key];
    V val = wr?.target;
    if (val == null) {
      val = ifAbsent();
      this[key] = val;
    }
    return val;
  }

  @override
  V? remove(Object? key) => _inner.remove(key)?.target;

  @override
  void removeWhere(bool Function(K key, V value) test) =>
      _inner.removeWhere((key, wr) {
        V val = wr?.target;
        return val != null && test(key, val);
      });

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) =>
      _inner.update(key, (wr) {
        V val = wr?.target;
        if (val != null) {
          val = update(val);
        } else if (ifAbsent != null) {
          val = ifAbsent();
        }
        return val == null ? null : WeakReference(val);
      })?.target;

  @override
  void updateAll(V Function(K key, V value) update) =>
      _inner.updateAll((key, wr) {
        V val = wr?.target;
        if (val == null) {
          return null;
        }
        val = update(key, val);
        return val == null ? null : WeakReference(val);
      });

  @override
  Iterable<V> get values => toMap().values;

}
