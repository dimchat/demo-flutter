/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'package:flutter/services.dart';


class RawKeyboardKey {
  RawKeyboardKey(this.value);

  final int value;

  bool get isShiftPressed => value & _ModifierKeyCode.shift == _ModifierKeyCode.shift;
  bool get isCtrlPressed => value & _ModifierKeyCode.ctrl == _ModifierKeyCode.ctrl;
  bool get isAltPressed => value & _ModifierKeyCode.alt == _ModifierKeyCode.alt;
  // apple
  bool get isMetaPressed => value & _ModifierKeyCode.meta == _ModifierKeyCode.meta;

  bool get isModified => isShiftPressed || isCtrlPressed || isAltPressed || isMetaPressed;

  @override
  String toString() => '<$runtimeType value="$value" />';

  @override
  bool operator ==(Object other) {
    int otherValue = -1;
    if (other is RawKeyboardKey) {
      if (identical(this, other)) {
        // same object
        return true;
      }
      otherValue = other.value;
    } else if (other is LogicalKeyboardKey) {
      otherValue = other.keyId;
    }
    assert(otherValue > 0, 'other key error: $other');
    return (otherValue & 0x0000ffff) == (value & 0x0000ffff);
  }

  @override
  int get hashCode => value;

  //
  //  Factory
  //
  static RawKeyboardKey logical(LogicalKeyboardKey key) =>
      RawKeyboardKey(key.keyId & 0x0000ffff);

  //
  //  Keyboard Keys
  //
  static final backspace  = logical(LogicalKeyboardKey.backspace);  // 0008
  static final tab        = logical(LogicalKeyboardKey.tab);        // 0009
  static final enter      = logical(LogicalKeyboardKey.enter);      // 000d
  static final escape     = logical(LogicalKeyboardKey.escape);     // 001b
  static final space      = logical(LogicalKeyboardKey.space);      // 0020

  static final capsLock   = logical(LogicalKeyboardKey.capsLock);   // 0104
  static final fn         = logical(LogicalKeyboardKey.fn);         // 0106
  static final fnLock     = logical(LogicalKeyboardKey.fnLock);     // 0107
  static final numLock    = logical(LogicalKeyboardKey.numLock);    // 010a

  static final arrowDown  = logical(LogicalKeyboardKey.arrowDown);  // 0301
  static final arrowLeft  = logical(LogicalKeyboardKey.arrowLeft);  // 0302
  static final arrowRight = logical(LogicalKeyboardKey.arrowRight); // 0303
  static final arrowUp    = logical(LogicalKeyboardKey.arrowUp);    // 0304

  static final end        = logical(LogicalKeyboardKey.end);        // 0305
  static final home       = logical(LogicalKeyboardKey.home);       // 0306
  static final pageDown   = logical(LogicalKeyboardKey.pageDown);   // 0307
  static final pageUp     = logical(LogicalKeyboardKey.pageUp);     // 0308
  static final insert     = logical(LogicalKeyboardKey.insert);     // 0407
  static final paste      = logical(LogicalKeyboardKey.paste);      // 0408

  static final pause      = logical(LogicalKeyboardKey.pause);      // 0509
  static final play       = logical(LogicalKeyboardKey.play);       // 050a

  static final f1         = logical(LogicalKeyboardKey.f1);         // 0801
  static final f2         = logical(LogicalKeyboardKey.f2);         // 0802
  static final f3         = logical(LogicalKeyboardKey.f3);         // 0803
  static final f4         = logical(LogicalKeyboardKey.f4);         // 0804
  static final f5         = logical(LogicalKeyboardKey.f5);         // 0805
  static final f6         = logical(LogicalKeyboardKey.f6);         // 0806
  static final f7         = logical(LogicalKeyboardKey.f7);         // 0807
  static final f8         = logical(LogicalKeyboardKey.f8);         // 0808
  static final f9         = logical(LogicalKeyboardKey.f9);         // 0809
  static final f10        = logical(LogicalKeyboardKey.f10);        // 080a
  static final f11        = logical(LogicalKeyboardKey.f11);        // 080b
  static final f12        = logical(LogicalKeyboardKey.f12);        // 080c

  static final delete     = logical(LogicalKeyboardKey.delete);     // 007f

  // modified enters
  static final altEnter   = RawKeyboardKey(enter.value | _ModifierKeyCode.alt);
  static final ctrlEnter  = RawKeyboardKey(enter.value | _ModifierKeyCode.ctrl);
  static final shiftEnter = RawKeyboardKey(enter.value | _ModifierKeyCode.shift);
  static final metaEnter  = RawKeyboardKey(enter.value | _ModifierKeyCode.meta);

}

abstract interface class _ModifierKeyCode {

  static const int shift = 0x10000000;
  static const int ctrl  = 0x01000000;
  static const int alt   = 0x00100000;

  // apple
  static const int meta  = 0x00010000;

}


class RawKeyboardChecker {
  factory RawKeyboardChecker() => _instance;
  static final RawKeyboardChecker _instance = RawKeyboardChecker._internal();
  RawKeyboardChecker._internal();

  bool _shift = false;
  bool _ctrl = false;
  bool _alt = false;

  bool _meta = false;  // apple command key

  RawKeyboardKey? checkKeyEvent(KeyEvent event) {
    LogicalKeyboardKey key = event.logicalKey;
    //
    //  Checking modifier keys
    //
    if (//key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      _shift = event is! KeyUpEvent;
      return null;
    }
    if (//key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      _ctrl = event is! KeyUpEvent;
      return null;
    }
    if (//key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      _alt = event is! KeyUpEvent;
      return null;
    }
    if (//key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      _meta = event is! KeyUpEvent;
      return null;
    }
    if (event is! KeyDownEvent) {
      return null;
    }
    //
    //  Checking for enter
    //
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return _shift ? RawKeyboardKey.shiftEnter
          : _ctrl ? RawKeyboardKey.ctrlEnter
          : _alt ? RawKeyboardKey.altEnter
          : _meta ? RawKeyboardKey.metaEnter
          : RawKeyboardKey.enter;
    }
    //
    //  Other keys
    //
    int value = key.keyId & 0x0000ffff;
    if (_shift) {
      value |= _ModifierKeyCode.shift;
    }
    if (_ctrl) {
      value |= _ModifierKeyCode.ctrl;
    }
    if (_alt) {
      value |= _ModifierKeyCode.alt;
    }
    if (_meta) {
      value |= _ModifierKeyCode.meta;
    }
    return RawKeyboardKey(value);
  }

}
