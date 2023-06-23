import 'package:flutter/material.dart';

class BadgeView extends StatelessWidget {
  const BadgeView(this.icon, this.number, {super.key});

  final Widget icon;
  final int number;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: const AlignmentDirectional(1.6, -1.6),
    children: [
      icon,
      if (number > 0)
        NumberView(number),
    ],
  );

}

class NumberView extends StatelessWidget {
  const NumberView(this.number, {super.key});

  final int number;

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
      child: Text(number < 100 ? number.toString() : '99+',
        style: const TextStyle(color: Colors.white, fontSize: 8),
      ),
    ),
  );

  // @override
  // Widget build(BuildContext context) => ClipOval(
  //   child: Container(
  //     alignment: Alignment.center,
  //     width: 12, height: 12,
  //     color: Colors.red,
  //     child: Text(number < 100 ? number.toString() : '99+',
  //       style: const TextStyle(color: Colors.white, fontSize: 8),
  //     ),
  //   ),
  // );

}
