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
import 'dart:io';

import 'package:dim_client/dim_client.dart';
import 'package:flutter/cupertino.dart';

import '../client/shared.dart';

/// ImageView
class Facade extends StatefulWidget {
  const Facade(FacadeProvider provider, {super.key})
      : _provider = provider;

  final FacadeProvider _provider;

  static Facade fromID(ID identifier, {double? width, double? height}) {
    return Facade(_AvatarProvider(identifier, width ?? 36, height ?? 36));
  }

  @override
  State<StatefulWidget> createState() => _FacadeState();

}

abstract class FacadeProvider {

  Widget get image;

  Future<bool> reload();

}

class _FacadeState extends State<Facade> {

  Future<void> _reload() async {
    widget._provider.reload().then((ok) {
      if (ok) {
        setState(() {
          Log.warning('Facade reloaded: ${widget._provider}');
        });
      // } else {
      //   Log.error('Facade reload failed: ${widget._provider}');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return widget._provider.image;
  }

}

class _AvatarProvider implements FacadeProvider {
  _AvatarProvider(this.identifier, this.width, this.height);

  final ID identifier;
  final double width;
  final double height;
  String? _path;

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz id="$identifier" width=$width, height=$height path=$_path />';
  }

  @override
  Widget get image {
    String? path = _path;
    if (path != null) {
      return Image.file(File(path), width: width, height: height);
    } else if (identifier.isUser) {
      return Icon(CupertinoIcons.profile_circled, size: width,);
    } else {
      return Icon(CupertinoIcons.group, size: width,);
    }
  }

  @override
  Future<bool> reload() async {
    if (identifier.isGroup) {
      // TODO: build group icon
      return false;
    }
    GlobalVariable shared = GlobalVariable();
    Pair<String?, Uri?> pair = await shared.facebook.getAvatar(identifier);
    _path = pair.first;
    return pair.first != null;
  }

}
