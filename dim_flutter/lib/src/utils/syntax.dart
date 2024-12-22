import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

import 'package:dim_client/ok.dart';

import '../ui/brightness.dart';


class SyntaxManager {
  factory SyntaxManager() => _instance;
  static final SyntaxManager _instance = SyntaxManager._internal();
  SyntaxManager._internal();

  bool _loaded = false;
  _DefaultSyntaxHighlighter? _dark;
  _DefaultSyntaxHighlighter? _light;

  Future<HighlighterTheme> getTheme(Brightness brightness) async {
    // 1. load grammars
    if (!_loaded) {
      _loaded = true;
      await Highlighter.initialize([
        'dart',
        // 'json',
        // 'sql',
        // 'yaml',
      ]);
    }
    // 2. load theme with brightness
    return await HighlighterTheme.loadForBrightness(brightness);
  }

  SyntaxHighlighter getHighlighter() {
    Brightness brightness = BrightnessDataSource().current;
    var pipe = brightness == Brightness.dark ? _dark : _light;
    if (pipe != null) {
      return pipe;
    } else if (brightness == Brightness.dark) {
      return _dark = _DefaultSyntaxHighlighter(brightness);
    } else {
      return _light = _DefaultSyntaxHighlighter(brightness);
    }
  }

}

class _DefaultSyntaxHighlighter with Logging implements SyntaxHighlighter {
  _DefaultSyntaxHighlighter(Brightness brightness) {
    _initialize(brightness);
  }

  Highlighter? _inner;

  void _initialize(Brightness brightness) async {
    HighlighterTheme theme = await SyntaxManager().getTheme(brightness);
    _inner = Highlighter(language: 'dart', theme: theme);
  }

  @override
  TextSpan format(String source) {
    TextSpan? res;
    try {
      res = _inner?.highlight(source);
      logInfo('syntax highlighter: $_inner');
    } catch (e, st) {
      logError('syntax error: $source\n error: $e, $st');
    }
    return res ?? TextSpan(text: source);
  }

}


abstract class VisualTextUtils {

  /// Calculate visual width
  static int getTextWidth(String text) {
    int width = 0;
    int index;
    int code;
    for (index = 0; index < text.length; ++index) {
      code = text.codeUnitAt(index);
      if (0x0000 <= code && code <= 0x007F) {
        // Basic Latin (ASCII)
        width += 1;
      } else if (0x0080 <= code && code <= 0x07FF) {
        // Latin-1 Supplement to CJK Unified Ideographs
        // ASCII or Latin-1 Supplement (includes most Western European languages)
        width += 1;
      } else {
        // Assume other characters are wide (e.g., CJK characters)
        width += 2;
      }
    }
    return width;
  }

  static String getSubText(String text, int maxWidth) {
    int width = 0;
    int index;
    int code;
    for (index = 0; index < text.length; ++index) {
      code = text.codeUnitAt(index);
      if (0x0000 <= code && code <= 0x007F) {
        // Basic Latin (ASCII)
        width += 1;
      } else if (0x0080 <= code && code <= 0x07FF) {
        // Latin-1 Supplement to CJK Unified Ideographs
        // ASCII or Latin-1 Supplement (includes most Western European languages)
        width += 1;
      } else {
        // Assume other characters are wide (e.g., CJK characters)
        width += 2;
      }
      if (width > maxWidth) {
        break;
      }
    }
    if (index == 0) {
      return '';
    }
    return text.substring(0, index);
  }

}
