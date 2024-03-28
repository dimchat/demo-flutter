import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:lnc/log.dart';

import '../widgets/browser.dart';

import 'brightness.dart';


class RichTextView extends StatefulWidget {
  const RichTextView({required this.text, this.onWebShare, super.key});

  final String text;
  final OnWebShare? onWebShare;

  @override
  State<StatefulWidget> createState() => _RichTextState();

}

class _RichTextState extends State<RichTextView> {

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: widget.text,
    selectable: true,
    extensionSet: md.ExtensionSet.gitHubWeb,
    syntaxHighlighter: _SyntaxManager().getHighlighter(),
    onTapLink: (text, href, title) {
      if (href != null) {
        Browser.open(context, url: href, onShare: widget.onWebShare,);
      }
    },
  );

}


class _SyntaxManager {
  factory _SyntaxManager() => _instance;
  static final _SyntaxManager _instance = _SyntaxManager._internal();
  _SyntaxManager._internal();

  bool _loaded = false;
  bool? _darkMode;
  _DefaultSyntaxHighlighter? _highlighter;

  Future<HighlighterTheme> getTheme(bool isDarkMode) async {
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
    HighlighterTheme theme = await HighlighterTheme.loadForBrightness(
      isDarkMode ? Brightness.dark : Brightness.light,
    );
    _darkMode = isDarkMode;
    return theme;
  }

  SyntaxHighlighter getHighlighter() {
    _DefaultSyntaxHighlighter? wrapper = _highlighter;
    bool isDarkMode = BrightnessDataSource().isDarkMode;
    if (wrapper == null || _darkMode != isDarkMode) {
      wrapper = _highlighter = _DefaultSyntaxHighlighter();
      getTheme(isDarkMode).then((theme) => wrapper?._inner = Highlighter(
        language: 'dart',
        theme: theme,
      ));
    }
    return wrapper;
  }

}

class _DefaultSyntaxHighlighter with Logging implements SyntaxHighlighter {
  _DefaultSyntaxHighlighter();

  Highlighter? _inner;

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
