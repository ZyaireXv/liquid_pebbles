import 'dart:math';

import 'package:flutter/material.dart';

import 'pebble_shape.dart';

/// 使用连续曲线裁剪鹅卵石外轮廓。
///
/// 这里不继续使用 `BorderRadius`，原因很直接：
/// `BorderRadius` 本质上只是在四个角上做椭圆圆角插值，中间边仍然是直线。
/// 当外部把形变幅度拉大时，卡片边缘就会暴露出“直线段”，看起来像被掰成了多边形。
/// 改成基于圆周采样点 + Catmull-Rom 插值之后，整个轮廓都由连续曲线组成，
/// 形变再明显，也不会退化出四条硬边。
class PebbleClipper extends CustomClipper<Path> {
  final PebbleShape shape;

  const PebbleClipper(this.shape);

  @override
  Path getClip(Size size) {
    if (shape.radialFactors.isEmpty) {
      return Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radiusX = size.width / 2;
    final radiusY = size.height / 2;

    const sampleCount = 48;
    final points = List<Offset>.generate(sampleCount, (index) {
      final unit = index / sampleCount;
      final t = unit * shape.radialFactors.length;
      final angle = -pi / 2 + (2 * pi * unit);
      final factor = _sampleFactor(t);
      return Offset(
        centerX + cos(angle) * radiusX * factor,
        centerY + sin(angle) * radiusY * factor,
      );
    });

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < sampleCount; index++) {
      final p0 = points[(index - 1 + sampleCount) % sampleCount];
      final p1 = points[index];
      final p2 = points[(index + 1) % sampleCount];
      final p3 = points[(index + 2) % sampleCount];

      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  double _sampleFactor(double t) {
    final count = shape.radialFactors.length;
    final i1 = t.floor() % count;
    final local = t - t.floor();
    final i0 = (i1 - 1 + count) % count;
    final i2 = (i1 + 1) % count;
    final i3 = (i1 + 2) % count;

    final p0 = shape.radialFactors[i0];
    final p1 = shape.radialFactors[i1];
    final p2 = shape.radialFactors[i2];
    final p3 = shape.radialFactors[i3];

    final local2 = local * local;
    final local3 = local2 * local;
    final value =
        0.5 *
        ((2 * p1) +
            (-p0 + p2) * local +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * local2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * local3);
    return value.clamp(0.72, 1.22);
  }

  @override
  bool shouldReclip(covariant PebbleClipper oldClipper) {
    if (oldClipper.shape.radialFactors.length != shape.radialFactors.length) {
      return true;
    }
    for (var index = 0; index < shape.radialFactors.length; index++) {
      if ((oldClipper.shape.radialFactors[index] - shape.radialFactors[index])
              .abs() >
          0.0001) {
        return true;
      }
    }
    return false;
  }
}
