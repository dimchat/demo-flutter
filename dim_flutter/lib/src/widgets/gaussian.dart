import 'dart:ui';

import 'package:flutter/cupertino.dart';

class FrostedGlassPage extends StatelessWidget {
  const FrostedGlassPage({super.key, required this.body});

  final Widget body;

  static void show(BuildContext context, Widget body) => showCupertinoDialog(
    context: context,
    builder: (context) => FrostedGlassPage(body: body),
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
      child: body,
    ),
  );

}

class GaussianInfo extends StatelessWidget {
  const GaussianInfo({super.key, required this.title, required this.message, this.width});

  final String title;
  final String message;
  final double? width;

  static void show(BuildContext context, String title, String message) =>
      FrostedGlassPage.show(context, GaussianInfo(title: title, message: message));

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Center(child: Text(title,
        style: const TextStyle(
          fontSize: 18,
          color: CupertinoColors.systemBlue,
          decoration: TextDecoration.none,
        ),
      )),
      Container(
        width: width ?? 256,
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        alignment: Alignment.topLeft,
        child: Text(message,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: CupertinoColors.systemGrey,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ],
  );

}
