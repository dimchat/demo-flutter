import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:dim_client/dim_common.dart';
import 'package:lnc/log.dart';

import '../client/shared.dart';
import '../pnf/auto_image.dart';
import '../pnf/image.dart';
import '../ui/brightness.dart';
import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';

import 'alert.dart';
import 'browse_html.dart';
import 'browser.dart';
import 'video_player.dart';


class TextPreviewPage extends StatefulWidget {
  const TextPreviewPage({super.key,
    required this.sender,
    required this.text,
    required this.onWebShare,
    required this.onVideoShare,
    this.previewing = false,
  });

  final ID sender;
  final String text;
  final OnWebShare? onWebShare;
  final OnVideoShare? onVideoShare;
  final bool previewing;

  static void open(BuildContext ctx, {
    required String text,
    required ID sender,
    required OnWebShare? onWebShare,
    required OnVideoShare? onVideoShare,
    bool previewing = false
  }) => showPage(
    context: ctx,
    builder: (context) => TextPreviewPage(text: text,
      sender: sender,
      onWebShare: onWebShare,
      onVideoShare: onVideoShare,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _body(),
            ),
          ),
        ],
      ),
      onTap: () => closePage(context),
    ),
  );

  Widget _body() => Container(
    padding: const EdgeInsets.all(32),
    alignment: AlignmentDirectional.centerStart,
    color: Styles.colors.textMessageBackgroundColor,
    child: _previewing ? _richText(context) : _plainText(context),
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
    child: RichTextView(
      sender: widget.sender,
      text: widget.text,
      onWebShare: widget.onWebShare,
      onVideoShare: widget.onVideoShare,
    ),
    onTap: () => closePage(context),
  );

}


class RichTextView extends StatefulWidget {
  const RichTextView({super.key,
    required this.sender,
    required this.text,
    required this.onWebShare,
    required this.onVideoShare,
  });

  final ID sender;
  final String text;
  final OnWebShare? onWebShare;
  final OnVideoShare? onVideoShare;

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
    onTapLink: (text, href, title) => _MarkdownUtils.openLink(context,
      sender: widget.sender,
      text: text, href: href, title: title,
      onWebShare: widget.onWebShare,
      onVideoShare: widget.onVideoShare,
    ),
    imageBuilder: (url, title, alt) => _MarkdownUtils.buildImage(context,
      url: url, title: title, alt: alt,
    ),
  );

}


enum _MimeType {
  image,
  video,
  other,
}
final List<String> _imageTypes = [
  'jpg', 'jpeg',
  'png',
  // 'gif',
  // 'bmp',
];
final List<String> _videoTypes = [
  'mp4',
  'mov',
  'avi',
  // 'wmv',
  // 'mkv',
  'mpg', 'mpeg',
  // '3gp', '3gpp',
  // 'rm', 'rmvb',
  'm3u', 'm3u8',
];

_MimeType? _checkFileType(String urlString) {
  // check extension (maybe the tail of query string)
  int pos = urlString.lastIndexOf('.');
  if (pos > 0) {
    String ext = urlString.substring(pos + 1).toLowerCase();
    if (_imageTypes.contains(ext)) {
      return _MimeType.image;
    } else if (_videoTypes.contains(ext)) {
      return _MimeType.video;
    }
  }
  return null;
}
Future<_MimeType> _checkUrlType(Uri url) async {
  _MimeType? type = _checkFileType(url.path);
  if (type == null && (url.hasQuery || url.hasFragment)) {
    type ??= _checkFileType(url.toString());
  }
  type ??= _MimeType.other;  // TODO: check from HTTP head
  return type;
}


abstract class _MarkdownUtils {

  static void openLink(BuildContext context, {
    required ID sender,
    required String text,
    required String? href,
    required String title,
    required OnWebShare? onWebShare,
    required OnVideoShare? onVideoShare,
  }) {
    Log.info('openLink: text="$text" href="$href" title="$title"');
    if (href == null || href.isEmpty) {
      return;
    }
    Uri? url = HtmlUri.parseUri(href);
    if (url == null) {
      Log.error('link href invalid: $href');
      Alert.show(context, 'Error', 'URL error: "$href"');
      return;
    } else if (url.scheme != 'http' && url.scheme != 'https') {
      assert(url.scheme == 'data', 'unknown link href: $href');
      Log.info('open data link: $url');
      // - data:text/html;charset=UTF-8;base64,
      // - data:text/plain;charset=UTF-8;base64,
      String path = url.path;
      if (path.startsWith('text/plain;')) {
        String? plain = _parseText(href);
        if (plain == null) {
          Log.error('text url error: $href');
          Alert.show(context, 'Error', 'Data error: "$href"');
        } else {
          TextPreviewPage.open(context,
            text: plain, sender: sender,
            onWebShare: onWebShare, onVideoShare: onVideoShare,
            previewing: true,
          );
        }
      } else {
        assert(path.startsWith('text/html;'), 'data url error: $href');
        Browser.open(context, url: href, onShare: onWebShare,);
      }
      return;
    }
    _checkUrlType(url).then((type) {
      if (type == _MimeType.image) {
        // show image
        Log.info('preview image: $url');
        var imageContent = FileContent.image(url: url,
          password: PlainKey.getInstance(),
        );
        _previewImage(context, imageContent);
      } else if (type == _MimeType.video) {
        // show video
        Log.info('play video: "$title" $url, text: "$text"');
        var pnf = PortableNetworkFile.createFromURL(url,
          PlainKey.getInstance(),
        );
        pnf['title'] = title;
        pnf['snapshot'] = _getSnapshot(text);
        VideoPlayerPage.open(context, url, pnf, onShare: onVideoShare);
      } else {
        // open other link
        Browser.open(context, url: url.toString(), onShare: onWebShare,);
      }
    });
  }

  // - data:text/plain;charset=UTF-8;base64,
  static String? _parseText(String href) {
    Uint8List? data = _parseData(href);
    if (data == null) {
      assert(false, 'failed to decode text body: $href');
      return null;
    }
    return UTF8.decode(data);
  }
  static Uint8List? _parseData(String href) {
    int pos = href.indexOf(',');
    if (pos > 6) {
      assert(href.substring(pos - 6, pos) == 'base64', 'data url error: $href');
    } else {
      pos = href.lastIndexOf(';');
      if (pos < 0) {
        Log.error('data url error: $href');
        return null;
      }
    }
    String body = href.substring(pos + 1);
    return Base64.decode(body);
  }

  static String? _getSnapshot(String text) {
    // Snapshot in alt text:
    //      [http://files.dim.chat/images/snapshot.jpg]
    //      [video-url=http://files.dim.chat/images/snapshot.jpg]
    //      [video src="http://files.dim.chat/images/snapshot.jpg"]
    int pos = text.indexOf('https://');
    if (pos < 0) {
      pos = text.indexOf('http://');
      if (pos < 0) {
        return null;
      }
    }
    String urlString = pos > 0 ? text.substring(pos) : text;
    // trim the tail
    pos = urlString.indexOf('"');
    if (pos < 0) {
      pos = urlString.indexOf(' ');
    }
    if (pos > 0) {
      urlString = urlString.substring(0, pos);
    }
    _MimeType? type = _checkFileType(urlString);
    if (type == _MimeType.image) {
      return urlString;
    }
    // TODO:
    return null;
  }

  //
  //  Image
  //

  static Widget buildImage(BuildContext context, {
    required Uri url,
    required String? title,
    required String? alt,
  }) {
    String scheme = url.scheme;
    if (scheme == 'data') {
      // - data:image/png;base64,
      Uint8List? data = _parseData(url.toString());
      if (data == null) {
        Log.error('failed to decode text body: $url');
        return _errorImage(url: url, title: title, alt: alt);
      }
      return ImageUtils.memoryImage(data);
    } else if (scheme != 'http' && scheme != 'https') {
      Log.error('image url error: $url');
      return _errorImage(url: url, title: title, alt: alt);
    }
    var plain = PlainKey.getInstance();
    var imageContent = FileContent.image(url: url, password: plain);
    var pnf = PortableNetworkFile.parse(imageContent);
    // check file type
    _MimeType? type = _checkFileType(url.path);
    if (type == null && (url.hasQuery || url.hasFragment)) {
      type ??= _checkFileType(url.toString());
    }
    Widget imageView;
    if (type != _MimeType.image) {
      Log.warning('unknown image url: $url');
      imageView = ImageUtils.networkImage(url.toString());
    } else if (pnf == null) {
      assert(false, 'should not happen: $url => $imageContent');
      imageView = ImageUtils.networkImage(url.toString());
    } else {
      imageView = NetworkImageFactory().getImageView(pnf);
    }
    return GestureDetector(
      onDoubleTap: () => _previewImage(context, imageContent),
      onLongPress: () => Alert.actionSheet(context, null, null,
        Alert.action(AppIcons.saveFileIcon, 'Save to Album'),
            () => saveImageContent(context, imageContent),
        // 'Save Image', () { },
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 256),
        child: imageView,
      ),
    );
  }

  static Widget _errorImage({
    required Uri url,
    required String? title,
    required String? alt,
  }) => Text(
    '<img src="$url" title="$title" alt="$alt" />',
    style: const TextStyle(color: CupertinoColors.systemRed),
  );

  static void _previewImage(BuildContext ctx, ImageContent imageContent) {
    var head = Envelope.create(sender: ID.kAnyone, receiver: ID.kAnyone);
    var msg = InstantMessage.create(head, imageContent);
    previewImageContent(ctx, imageContent, [msg]);
  }

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
