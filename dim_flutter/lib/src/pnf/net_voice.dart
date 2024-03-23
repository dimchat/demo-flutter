/* license: https://mit-license.org
 *
 *  PNF : Portable Network File
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
import 'package:flutter/cupertino.dart';

import 'package:dim_client/dim_client.dart';
import 'package:lnc/notification.dart' as lnc;
import 'package:pnf/dos.dart';
import 'package:pnf/pnf.dart' show PortableNetworkStatus;

import '../channels/manager.dart';
import '../common/constants.dart';
import '../ui/icons.dart';

import '../ui/styles.dart';
import 'net_base.dart';


/// Factory for Auto Download Audio
class NetworkAudioFactory {
  factory NetworkAudioFactory() => _instance;
  static final NetworkAudioFactory _instance = NetworkAudioFactory._internal();
  NetworkAudioFactory._internal();

  final Map<Uri, _PortableAudioView> _views = WeakValueMap();

  PortableNetworkView getAudioView(AudioContent content, {Color? color, Color? backgroundColor}) {
    PortableNetworkFile? pnf = PortableNetworkFile.parse(content);
    if (pnf == null) {
      throw FormatException('PNF error: $content');
    }
    Uri? url = pnf.url;
    var loader = PortableNetworkFactory().getLoader(pnf);
    if (url == null) {
      return _PortableAudioView(loader, color: color, backgroundColor: backgroundColor,);
    }
    _PortableAudioView? view = _views[url];
    if (view == null) {
      view = _PortableAudioView(loader, color: color, backgroundColor: backgroundColor,);
      _views[url] = view;
    }
    return view;
  }

}


/// View for show Audio Content
class _PortableAudioView extends PortableNetworkView {
  _PortableAudioView(super.loader, {this.color, this.backgroundColor});

  final Color? color;
  final Color? backgroundColor;

  final _AudioPlayInfo _info = _AudioPlayInfo();

  Uri? get url => pnf.url;

  Future<String?> get cacheFilePath async {
    String? path = _info.cacheFilePath;
    if (path == null) {
      path = await loader.cacheFilePath;
      if (path != null && await Paths.exists(path)) {
        _info.cacheFilePath = path;
      }
    }
    return path;
  }

  @override
  State<StatefulWidget> createState() => _PortableAudioState();

}

class _AudioPlayInfo {
  String? cacheFilePath;
  bool playing = false;
}

class _PortableAudioState extends PortableNetworkState<_PortableAudioView> {
  _PortableAudioState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPlayFinished);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kPlayFinished);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    super.onReceiveNotification(notification);
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kPlayFinished) {
      String? path = userInfo?['path'];
      if (path != await widget.cacheFilePath) {
        return;
      }
      if (mounted) {
        setState(() {
          widget._info.playing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? progress = getProgress();
    return Container(
      width: 200,
      color: widget.backgroundColor,
      padding: Styles.audioMessagePadding,
      child: GestureDetector(
        onTap: _togglePlay,
        child: Row(
          children: [
            _button(progress),
            Expanded(
              flex: 1,
              child: progress ?? Text('${_duration ?? 0} s',
                textAlign: TextAlign.center,
                style: TextStyle(color: widget.color, ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlay() async {
    ChannelManager man = ChannelManager();
    String? path = await widget.cacheFilePath;
    if (widget._info.playing) {
      await man.audioChannel.stopPlay(path);
      if (mounted) {
        setState(() {
          widget._info.playing = false;
        });
      }
    } else if (path != null) {
      if (mounted) {
        setState(() {
          widget._info.playing = true;
        });
      }
      await man.audioChannel.startPlay(path);
    }
  }

  String? get _duration {
    return widget.pnf.getDouble('duration', 0)?.toStringAsFixed(3);
  }

  Widget _button(Widget? progress) => progress != null
      ? Icon(AppIcons.waitAudioIcon, color: widget.color, ) : widget._info.playing
      ? Icon(AppIcons.playingAudioIcon, color: widget.color)
      : Icon(AppIcons.playAudioIcon, color: widget.color);

  Widget? getProgress() {
    var loader = widget.loader;
    PortableNetworkStatus pns = loader.status;
    if (pns == PortableNetworkStatus.success ||
        pns == PortableNetworkStatus.init) {
      return null;
    }
    String text;
    IconData? icon;
    Color? color;
    // check status
    if (pns == PortableNetworkStatus.error) {
      text = 'Error';
      icon = AppIcons.decryptErrorIcon;
      color = CupertinoColors.systemRed;
    } else if (pns == PortableNetworkStatus.downloading) {
      double len = loader.total.toDouble();
      double value = len > 0 ? loader.count * 100.0 / len : 0.0;
      if (value < 100.0) {
        text = '${value.toStringAsFixed(1)}%';
      } else {
        text = 'Decrypting';
        icon = AppIcons.decryptingIcon;
      }
    } else if (pns == PortableNetworkStatus.decrypting) {
      text = 'Decrypting';
      icon = AppIcons.decryptingIcon;
    } else if (pns == PortableNetworkStatus.waiting) {
      text = 'Waiting';
    } else {
      assert(false, 'status error: $pns');
      return null;
    }
    color ??= widget.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text,
          style: TextStyle(color: color,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        icon == null
            ? CupertinoActivityIndicator(color: color)
            : Icon(icon, color: color),
      ],
    );
  }

}
