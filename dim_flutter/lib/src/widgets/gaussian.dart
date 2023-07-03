import 'dart:ui';

import 'package:flutter/cupertino.dart';

class GaussianPage extends StatelessWidget {
  const GaussianPage({super.key, required this.child});

  final Widget child;

  static void show(BuildContext context, Widget child) => showCupertinoDialog(
    context: context,
    builder: (context) => GaussianPage(child: child),
  );

  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaY: 8.0, sigmaX: 8.0),
    child: Stack(
      children: [
        GestureDetector(onTap: () => Navigator.pop(context)),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _body(),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _body() => ClipRect(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: CupertinoColors.white,
      ),
      child: child,
    ),
  );

}

class FrostedGlassPage extends StatelessWidget {
  const FrostedGlassPage({super.key, this.head, this.body, this.width});

  final Widget? head;
  final Widget? body;
  final double? width;

  static void show(BuildContext context,
      {String? title, String? message, Widget? head, Widget? body, double? width}) {
    if (head == null && title != null) {
      head = Text(title,
        style: const TextStyle(
          fontSize: 18,
          color: CupertinoColors.systemBlue,
          decoration: TextDecoration.none,
        ),
      );
    }
    if (body == null && message != null) {
      body = Text(message,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: CupertinoColors.systemGrey,
          decoration: TextDecoration.none,
        ),
      );
    }
    return GaussianPage.show(context, FrostedGlassPage(head: head, body: body, width: width,));
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (head != null)
      Container(
        width: width ?? 256,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: head,
      ),
      if (body != null)
      Container(
        width: width ?? 256,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.topLeft,
        child: body,
      ),
    ],
  );

}
