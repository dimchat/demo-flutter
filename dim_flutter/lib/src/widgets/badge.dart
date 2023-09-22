import 'package:flutter/material.dart';

class IconView extends StatelessWidget {
  const IconView(this.icon, {required this.badge, required this.alignment, super.key});

  final Widget icon;
  final Widget badge;
  final AlignmentGeometry alignment;

  static Widget fromNumber(Widget icon, int number) {
    Widget? badge = IconBadge.fromInt(number);
    return badge == null ? icon : IconView(icon, badge: badge, alignment: IconBadge.alignment,);
  }
  static Widget fromSpot(Widget icon, int number) {
    Widget? badge = IconSpot.fromInt(number);
    return badge == null ? icon : IconView(icon, badge: badge, alignment: IconSpot.alignment,);
  }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: alignment,
    children: [icon, badge],
  );

}

class IconSpot extends StatelessWidget {
  const IconSpot({super.key});

  static const AlignmentGeometry alignment = AlignmentDirectional(1.2, -1.2);

  static IconSpot? fromInt(int number) {
    if (number <= 0) {
      return null;
    }
    return const IconSpot();
  }

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Container(
      width: 8,
      height: 8,
      color: Colors.red,
    ),
  );

}

class IconBadge extends StatelessWidget {
  const IconBadge(this.text, {super.key});

  final String text;

  static const AlignmentGeometry alignment = AlignmentDirectional(1.4, -1.4);

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
