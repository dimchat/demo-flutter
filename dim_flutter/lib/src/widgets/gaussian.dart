import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../ui/styles.dart';


class GaussianPage extends StatelessWidget {
  const GaussianPage({super.key, required this.child, this.locked = false});

  final Widget child;
  final bool locked;

  static void show(BuildContext context, Widget child) => showCupertinoDialog(
    context: context,
    builder: (context) => GaussianPage(child: child),
  );

  static void lock(BuildContext context, Widget child) => showCupertinoDialog(
    context: context,
    builder: (context) => GaussianPage(locked: true, child: child,),
  );

  @override
  Widget build(BuildContext context) {
    Widget view = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _body(),
          ],
        ),
      ],
    );
    if (!locked) {
      view = Stack(
        children: [
          GestureDetector(onTap: () => Navigator.pop(context)),
          view,
        ],
      );
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaY: 8.0, sigmaX: 8.0),
      child: view,
    );
  }

  Widget _body() => ClipRect(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        // color: CupertinoColors.systemFill,
        color: Styles.colors.pageMessageBackgroundColor,
      ),
      child: child,
    ),
  );

}

class FrostedGlassPage extends StatelessWidget {
  const FrostedGlassPage({super.key, this.head, this.body, this.tail, this.width});

  final Widget? head;
  final Widget? body;
  final Widget? tail;
  final double? width;

  static void show(BuildContext context,
      {String? title, String? message, Widget? head, Widget? body, Widget? tail, double? width}) {
    if (head == null && title != null) {
      head = buildHead(title);
    }
    if (body == null && message != null) {
      body = buildBody(message);
    }
    return GaussianPage.show(context, FrostedGlassPage(head: head, body: body, tail: tail, width: width,));
  }

  static void lock(BuildContext context,
      {String? title, String? message, Widget? head, Widget? body, Widget? tail, double? width}) {
    if (head == null && title != null) {
      head = buildHead(title);
    }
    if (body == null && message != null) {
      body = buildBody(message);
    }
    return GaussianPage.lock(context, FrostedGlassPage(head: head, body: body, tail: tail, width: width,));
  }

  static Widget buildHead(String title) => Text(title,
    style: const TextStyle(
      fontSize: 18,
      color: CupertinoColors.systemBlue,
      decoration: TextDecoration.none,
    ),
  );
  static Widget buildBody(String message) => Text(message,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: CupertinoColors.systemGrey,
      decoration: TextDecoration.none,
    ),
  );

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
      if (tail != null)
      Container(
        width: width ?? 256,
        // padding: const EdgeInsets.all(2),
        alignment: Alignment.center,
        child: tail,
      ),
    ],
  );

}
