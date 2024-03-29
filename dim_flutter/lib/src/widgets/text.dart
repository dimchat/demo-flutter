import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:dim_client/dim_common.dart';
import 'package:lnc/log.dart';

import '../client/shared.dart';
import '../ui/brightness.dart';

import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';
import 'browser.dart';


class TextPreviewPage extends StatefulWidget {
  const TextPreviewPage({super.key,
    required this.sender, required this.text, this.onWebShare, this.previewing = false});

  final ID sender;
  final String text;
  final OnWebShare? onWebShare;
  final bool previewing;

  static void open(BuildContext ctx, {
    required String text,
    required ID sender,
    OnWebShare? onWebShare,
    bool previewing = false
  }) => showPage(
    context: ctx,
    builder: (context) => TextPreviewPage(text: text,
      sender: sender,
      onWebShare: onWebShare,
      previewing: previewing,
    ),
  );

  @override
  State<StatefulWidget> createState() => _TextPreviewState();

}

class _TextPreviewState extends State<TextPreviewPage> {

  String? _back;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    setState(() {
      _previewing = widget.previewing;
    });
    _refresh();
  }

  void _refresh() async {
    GlobalVariable shared = GlobalVariable();
    String name = await shared.facebook.getName(widget.sender);
    if (mounted) {
      setState(() {
        _back = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      previousPageTitle: _back,
      trailing: _previewing ? _richButton() : _plainButton(),
    ),
    body: GestureDetector(
      child: Container(
        padding: const EdgeInsets.only(left: 32, right: 32),
        alignment: AlignmentDirectional.centerStart,
        color: Styles.colors.textMessageBackgroundColor,
        child: SingleChildScrollView(
          // child: _richTextView(context, _text, widget.onWebShare),
          child: Container(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: _previewing ? _richText(context) : _plainText(context),
          ),
        ),
      ),
      onTap: () => closePage(context),
    ),
  );

  Widget _plainButton() => IconButton(
    icon: const Icon(AppIcons.plainTextIcon,
      color: CupertinoColors.systemGrey,
      size: 24,
    ),
    onPressed: () => setState(() => _previewing = true),
  );
  Widget _richButton() => IconButton(
    icon: const Icon(AppIcons.richTextIcon,
      color: CupertinoColors.link,
      size: 24,
    ),
    onPressed: () => setState(() => _previewing = false),
  );

  Widget _plainText(BuildContext context) => SelectableText(widget.text,
    style: const TextStyle(
      fontSize: 18,
    ),
    onTap: () => closePage(context),
  );

  Widget _richText(BuildContext context) => GestureDetector(
    child: RichTextView(text: widget.text,
      onWebShare: widget.onWebShare,
    ),
    onTap: () => closePage(context),
  );

}


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
    HighlighterTheme theme = await _SyntaxManager().getTheme(brightness);
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
