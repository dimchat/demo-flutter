/// https://pub.dev/packages/circle_progress
///
/// The current Dart SDK version is 3.1.5.
///
/// Because dim_flutter depends on circle_progress any
/// which doesn't support null safety, version solving failed.
///
/// The lower bound of "sdk: '>=2.1.0 <3.0.0'" must be 2.12.0 or higher
/// to enable null safety.
///
/// So I can only copy its codes here and upgraded to adapt the new SDK version.
///                                             -- Albert Moky @ 2023-11-24

import 'package:flutter/material.dart';
import 'dart:math';

class CircleProgressWidget extends StatefulWidget {
  final Progress progress;

  const CircleProgressWidget({super.key, required this.progress});

  @override
  State<StatefulWidget> createState() => _CircleProgressWidgetState();

  static CircleProgressWidget from(double value,
      {required Color color, required Color backgroundColor,
        TextStyle? textStyle, String? completeText,
        double radius=32, double strokeWidth=2}) =>
      CircleProgressWidget(progress: Progress(value,
        color: color,
        backgroundColor: backgroundColor,
        textStyle: textStyle,
        radius: radius,
        strokeWidth: strokeWidth,
        completeText: completeText ?? 'OK',
      ));

}

///信息描述类 [value]为进度，在0~1之间,进度条颜色[color]，
///未完成的颜色[backgroundColor],圆的半径[radius],线宽[strokeWidth]
///小点的个数[dotCount] 样式[style] 完成后的显示文字[completeText]
class Progress {
  double value;
  Color color;
  Color backgroundColor;
  double radius;
  double strokeWidth;
  int dotCount;
  TextStyle? textStyle;
  String? completeText;

  Progress(this.value, {
    required this.color,
    required this.backgroundColor,
    this.radius = 32,
    this.strokeWidth = 2,
    this.dotCount = 36,
    this.textStyle,
    this.completeText,
  });
}

class _CircleProgressWidgetState extends State<CircleProgressWidget> {

  @override
  Widget build(BuildContext context) {
    var progress = SizedBox(
      width: widget.progress.radius * 2,
      height: widget.progress.radius * 2,
      child: CustomPaint(
        painter: ProgressPainter(widget.progress),
      ),
    );
    double value = widget.progress.value * 100;
    String completeText = widget.progress.completeText ?? '';
    String text;
    double fontSize;
    if (value < 100.0 || completeText.isEmpty) {
      text = value.toStringAsFixed(0);
      fontSize = widget.progress.radius / 2;
    } else {
      text = completeText;
      fontSize = widget.progress.radius / 4;
    }
    TextStyle style = widget.progress.textStyle
        ?? TextStyle(color: widget.progress.color,
          fontSize: fontSize,
          decoration: TextDecoration.none,
        );
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        progress,
        Text(text, style: style),
      ],
    );
  }
}

class ProgressPainter extends CustomPainter {
  final Progress _progress;
  late Paint _paint;
  late Paint _arrowPaint;
  late Path _arrowPath;
  late double _radius;

  ProgressPainter(
      this._progress,
      ) {
    _arrowPath=Path();
    _arrowPaint=Paint();
    _paint = Paint();
    _radius = _progress.radius - _progress.strokeWidth / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;
    canvas.clipRect(rect); //裁剪区域
    canvas.translate(_progress.strokeWidth / 2, _progress.strokeWidth / 2);
    canvas.save();
    _paint
      ..style = PaintingStyle.stroke
      ..color = _progress.backgroundColor
      ..strokeWidth = _progress.strokeWidth;
    canvas.drawCircle(Offset(_radius, _radius), _radius, _paint);
    //进度条
    _paint
      ..color = _progress.color
      ..strokeWidth = _progress.strokeWidth * 1.2
      ..strokeCap = StrokeCap.round;
    double sweepAngle = _progress.value * 360; //完成角度
    // print(sweepAngle);
    canvas.drawArc(Rect.fromLTRB(0, 0, _radius * 2, _radius * 2),
        -90 / 180 * pi, sweepAngle / 180 * pi, false, _paint);
    canvas.restore();

    canvas.save();
    canvas.translate(_radius, _radius);
    canvas.rotate((180+_progress.value*360)/180*pi);
    var half= _radius/2;
    var eg= _radius/50;//单位长
    _arrowPath.moveTo(0,-half-eg*2);
    _arrowPath.relativeLineTo(eg*2, eg*6);
    _arrowPath.lineTo(0, -half+eg*2);
    _arrowPath.lineTo(0,-half-eg*2);
    _arrowPath.relativeLineTo(-eg*2, eg*6);
    _arrowPath.lineTo(0, -half+eg*2);
    _arrowPath.lineTo(0,-half-eg*2);
    canvas.drawPath(_arrowPath, _arrowPaint);
    canvas.restore();
    drawDot(canvas);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

  void drawDot(Canvas canvas) {
    canvas.save();
    int num = _progress.dotCount;
    canvas.translate(_radius, _radius);
    for (double i = 0; i <num; i++) {
      canvas.save();
      double deg = 360 / num * i;
      canvas.rotate(deg / 180 * pi);
      _paint
        ..strokeWidth = _progress.strokeWidth / 2
        ..color = _progress.backgroundColor
        ..strokeCap = StrokeCap.round;
      if (i * (360 / num) <= _progress.value * 360) {
        _paint.color = _progress.color;
      }
      canvas.drawLine(
          Offset(0, _radius * 3 / 4), Offset(0, _radius * 4 / 5), _paint);
      canvas.restore();
    }
    canvas.restore();
  }
}

