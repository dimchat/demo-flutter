/* license: https://mit-license.org
 *
 *  Cast Screen
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
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/nav.dart';
import '../ui/styles.dart';
import '../widgets/table.dart';

import 'device.dart';


class AirPlayPicker extends StatefulWidget {
  const AirPlayPicker({super.key, required this.url});

  final Uri url;

  static void open(BuildContext context, Uri url) => showPage(
    context: context,
    builder: (context) => AirPlayPicker(url: url),
  );

  @override
  State<StatefulWidget> createState() => _AirPlayState();

}

class _AirPlayState extends State<AirPlayPicker> {

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    var man = ScreenManager();
    man.getDevices(true).then((_) {
      if (mounted) {
        setState(() {
        });
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      title: Text('Select TV'.tr),
    ),
    body: Center(
      child: buildScrollView(
        enableScrollbar: true,
        child: Column(
          children: _deviceList(context),
        ),
      ),
    ),
  );

  List<Widget> _deviceList(BuildContext context) {
    List<Widget> buttons = [];
    var man = ScreenManager();
    var devices = man.devices;
    for (var tv in devices) {
      buttons.add(TextButton(
        onPressed: () => tv.castURL(widget.url).then((_) => closePage(context)),
        child: Text(tv.friendlyName),
      ));
    }
    if (man.scanning) {
      buttons.add(const CupertinoActivityIndicator());
    } else if (devices.isEmpty) {
      buttons.add(Text('TV not found'.tr));
      buttons.add(TextButton(
        onPressed: () => _refresh(),
        child: Text('Search again'.tr),
      ));
    } else {
      buttons.add(TextButton(
        onPressed: () => _refresh(),
        child: Text('Refresh'.tr),
      ));
    }
    return buttons;
  }

}
