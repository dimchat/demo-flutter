import 'package:flutter/material.dart';

class IconView extends StatelessWidget {
  const IconView(this.icon, this.badge, {super.key});

  final Widget icon;
  final Widget? badge;

  static Widget from(Widget icon, int number) {
    Widget? badge = IconBadge.fromInt(number);
    return badge == null ? icon : IconView(icon, badge);
  }

  @override
  Widget build(BuildContext context) => badge == null ? icon : Stack(
    alignment: const AlignmentDirectional(1.6, -1.6),
    children: [icon, badge!],
  );

}

class IconBadge extends StatelessWidget {
  const IconBadge(this.text, {super.key});

  final String text;

  static IconBadge? fromInt(int number) {
    if (number <= 0) {
      return null;
    }
    String text = number > 99 ? '99+' : number.toString();
    return IconBadge(text);
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Container(
      width: 16, height: 16,
      alignment: Alignment.center,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.red,
      ),
      child: Text(text,
        style: const TextStyle(color: Colors.white, fontSize: 8),
      ),
    ),
  );

}

class NumberBubble extends IconBadge {
  const NumberBubble(super.text, {super.key});

  static Widget? fromInt(int number) {
    return IconBadge.fromInt(number);
  }

}
