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
///  Weak Set
///

class WeakSet<E extends Object> implements Set<E> {
  WeakSet() : _inner = {};

  final Set<WeakReference<dynamic>> _inner;

  @override
  void clear() => _inner.clear();

  @override
  Set<E> toSet() {
    Set<E> set = {};
    E? item;
    Set<WeakReference<dynamic>> ghosts = {};
    for (WeakReference<dynamic> wr in _inner) {
      item = wr.target;
      if (item == null) {
        // target released, remove the reference from inner set later
        ghosts.add(wr);
      } else {
        set.add(item);
      }
    }
    _inner.removeAll(ghosts);
    return set;
  }

  @override
  List<E> toList({bool growable = true}) => toSet().toList(growable: growable);

  @override
  Iterator<E> get iterator => toSet().iterator;

  @override
  int get length => toSet().length;

  @override
  bool get isEmpty {
    for (var wr in _inner) {
      if (wr.target != null) {
        return false;
      }
    }
    return true;
  }

  @override
  bool get isNotEmpty => !isEmpty;

  @override
  E get first {
    E? item;
    for (var wr in _inner) {
      item = wr.target;
      if (item != null) {
        return item;
      }
    }
    throw StateError('empty');
  }

  @override
  E get last {
    E? got;
    E? item;
    for (var wr in _inner) {
      item = wr.target;
      if (item != null) {
        got = item;
      }
    }
    if (got == null) {
      throw StateError('empty');
    }
    return got;
  }

  @override
  E get single {
    E? got;
    E? item;
    for (var wr in _inner) {
      item = wr.target;
      if (item != null) {
        if (got == null) {
          // first
          got = item;
        } else {
          // second
          throw StateError('more then one element');
        }
      }
    }
    if (got == null) {
      throw StateError('empty');
    }
    return got;
  }

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      _inner.firstWhere((element) {
        E? item = element.target;
        return item != null && test(element.target);
      }, orElse: orElse == null ? null : () {
        return WeakReference(orElse());
      }).target;

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      _inner.lastWhere((element) {
        E? item = element.target;
        return item != null && test(element.target);
      }, orElse: orElse == null ? null : () {
        return WeakReference(orElse());
      }).target;

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      _inner.singleWhere((element) {
        E? item = element.target;
        return item != null && test(element.target);
      }, orElse: orElse == null ? null : () {
        return WeakReference(orElse());
      }).target;

  @override
  bool any(bool Function(E element) test) =>
      _inner.any((element) {
        E? item = element.target;
        return item != null && test(element.target);
      });

  @override
  bool every(bool Function(E element) test) =>
      _inner.every((element) {
        E? item = element.target;
        return item != null && test(element.target);
      });

  @override
  E? lookup(Object? object)  {
    dynamic item;
    for (var wr in _inner) {
      item = wr.target;
      if (item == object) {
        return item;
      }
    }
    return null;
  }

  @override
  bool contains(Object? value) {
    for (var wr in _inner) {
      if (wr.target == value) {
        return true;
      }
    }
    return false;
  }

  @override
  bool containsAll(Iterable<Object?> other) {
    for (var item in other) {
      if (!contains(item)) {
        return false;
      }
    }
    return true;
  }

  @override
  E elementAt(int index) {
    assert(index >= 0, 'out of range: $index');
    E? item;
    int pos = -1;
    for (var wr in _inner) {
      item = wr.target;
      if (item == null) {
        // skip empty item
      } else if (++pos == index) {
        // got it
        break;
      }
    }
    assert(pos == index, 'out of range: $index, size=${pos + 1}');
    return item!;
  }

  @override
  bool add(E value) => !contains(value) && _inner.add(WeakReference(value));

  @override
  void addAll(Iterable<E> elements) {
    for (var item in elements) {
      add(item);
    }
  }

  @override
  bool remove(Object? value) {
    for (var wr in _inner) {
      if (wr.target == value) {
        _inner.remove(wr);
        return true;
      }
    }
    return false;
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    Set<dynamic> removing = {};
    for (var item in elements) {
      for (var wr in _inner) {
        if (wr.target == item) {
          removing.add(wr);
        }
      }
    }
    return _inner.removeAll(removing);
  }

  @override
  void removeWhere(bool Function(E element) test) =>
      _inner.removeWhere((element) {
        E? item = element.target;
        return item != null && test(element.target);
      });

  @override
  Set<E> difference(Set<Object?> other) => toSet().difference(other);

  @override
  Set<E> intersection(Set<Object?> other) => toSet().intersection(other);

  @override
  void forEach(void Function(E element) action) => toSet().forEach(action);

  @override
  String join([String separator = ""]) => toSet().join(separator);

  @override
  Set<E> union(Set<E> other) => toSet().union(other);

  @override
  Set<R> cast<R>() => toSet().cast();

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) =>
      toSet().expand(toElements);

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      toSet().fold(initialValue, combine);

  @override
  Iterable<E> followedBy(Iterable<E> other) => toSet().followedBy(other);

  @override
  Iterable<T> map<T>(T Function(E e) toElement) => toSet().map(toElement);

  @override
  E reduce(E Function(E value, E element) combine) => toSet().reduce(combine);

  @override
  void retainAll(Iterable<Object?> elements) => toSet().retainAll(elements);

  @override
  void retainWhere(bool Function(E element) test) => toSet().retainWhere(test);

  @override
  Iterable<E> skip(int count) => toSet().skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E value) test) => toSet().skipWhile(test);

  @override
  Iterable<E> take(int count) => toSet().take(count);

  @override
  Iterable<E> takeWhile(bool Function(E value) test) => toSet().takeWhile(test);

  @override
  Iterable<E> where(bool Function(E element) test) => toSet().where(test);

  @override
  Iterable<T> whereType<T>() => toSet().whereType();
}
