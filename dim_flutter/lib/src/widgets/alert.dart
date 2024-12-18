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
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class Alert {

  static void show(BuildContext context, String? title, dynamic body,
      {VoidCallback? callback}) {
    if (body is String) {
      body = Text(body);
    }
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: title == null || title.isEmpty ? null : Text(title.tr),
        content: body,
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              if (callback != null) {
                callback();
              }
            },
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
  }

  static void confirm(BuildContext context, String? title, dynamic body,
      {String? okTitle, VoidCallback? okAction,
        String? cancelTitle, VoidCallback? cancelAction}) {
    okTitle ??= 'OK';
    cancelTitle ??= 'Cancel';
    if (body is String) {
      body = Text(body);
    }
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: title == null || title.isEmpty ? null : Text(title.tr),
        content: body,
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              if (cancelAction != null) {
                cancelAction();
              }
            },
            child: Text(cancelTitle!.tr),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              if (okAction != null) {
                okAction();
              }
            },
            isDestructiveAction: true,
            child: Text(okTitle!.tr),
          ),
        ],
      ),
    );
  }

  static void actionSheet(BuildContext context, String? title, String? message,
      dynamic action1, VoidCallback callback1, [
        dynamic action2, VoidCallback? callback2,
        dynamic action3, VoidCallback? callback3,
      ]) => showCupertinoModalPopup(context: context,
    builder: (context) => CupertinoActionSheet(
      title: title == null || title.isEmpty ? null : Text(title.tr),
      message: message == null || message.isEmpty ? null : Text(message),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            callback1();
          },
          child: action1 is String ? Text(action1.tr) : action1,
        ),
        if (action2 != null)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (callback2 != null) {
                callback2();
              }
            },
            child: action2 is String ? Text(action2.tr) : action2,
          ),
        if (action3 != null)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (callback3 != null) {
                callback3();
              }
            },
            child: action3 is String? Text(action3.tr) : action3,
          ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: Text('Cancel'.tr),
        ),
      ],
    ),
  );

  static Widget action(IconData icon, String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon),
      const SizedBox(width: 12,),
      Text(text.tr),
    ],
  );

}
