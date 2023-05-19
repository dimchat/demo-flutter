import 'package:flutter/material.dart';

class BadgeView extends StatelessWidget {
  const BadgeView(this.icon, this.number, {super.key});

  final Widget icon;
  final int number;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: const AlignmentDirectional(1.5, -1.5),
    children: [
      icon,
      if (number > 0)
        _badge(number),
    ],
  );

  static Widget _badge(int number) => ClipOval(
    child: Container(
      alignment: Alignment.center,
      width: 12, height: 12,
      color: Colors.red,
      child: Text(number < 100 ? number.toString() : '...',
        style: const TextStyle(color: Colors.white, fontSize: 8),
      ),
    ),
  );

}
