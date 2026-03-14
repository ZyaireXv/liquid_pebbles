import 'dart:math';
import 'package:flutter/material.dart';

import 'pebble_shape.dart';

/// 描述一枚水滴卡片的基础外观信息
class PebbleCardSpec {
  /// 宽度
  final double width;

  /// 高度
  final double height;

  /// 出生时的相对锚点 (水平 0~1，垂直 0~1)
  final Offset anchor;

  /// 是否支持随时间继续自发位置游走
  final bool animatePosition;

  const PebbleCardSpec({
    required this.width,
    required this.height,
    required this.anchor,
    this.animatePosition = true,
  });
}

/// 维护单枚水滴卡片在舞台上的动力学状态和时间戳
class PebbleNodeState {
  final PebbleCardSpec spec;

  // 随机游走时的速度上下限与抖动程度
  final double _minSpeed;
  final double _maxSpeed;
  final double _jitterStrength;
  final double _steerLerpPerSecond;

  /// 当前所处的中心物理坐标
  late Offset center;
  bool hasPosition = false;

  Offset velocity = Offset.zero;
  Offset targetVelocity = Offset.zero;

  /// 当前根据时间实时计算出的形状
  late PebbleShape currentShape;

  // 独有时间戳偏移，避免多个实例发生“同频共振”的机械感
  final double _shapeTimeOffset;
  final List<double> _shapeStaticBiases;
  final List<double> _shapePhaseOffsets;
  final List<double> _shapeSpeedOffsets;
  final double _shapeAxisBiasX;
  final double _shapeAxisBiasY;
  final double _shapeLobeBias;
  final double _shapeAngleOffset;

  Duration _nextSteerAt = Duration.zero;

  PebbleNodeState({required this.spec, required Random random})
    : _minSpeed = 9 + random.nextDouble() * 6.0,
      _maxSpeed = 29 + random.nextDouble() * 13.0,
      _jitterStrength = 3 + random.nextDouble() * 5.0,
      _steerLerpPerSecond = 1.2 + random.nextDouble() * 1.1,
      _shapeTimeOffset = random.nextDouble() * 1000.0,
      _shapeStaticBiases = List<double>.generate(
        PebbleShape.factorCount,
        (_) => (random.nextDouble() - 0.5) * 0.08,
      ),
      _shapePhaseOffsets = List<double>.generate(
        PebbleShape.factorCount,
        (_) => (random.nextDouble() - 0.5) * 1.3,
      ),
      _shapeSpeedOffsets = List<double>.generate(
        PebbleShape.factorCount,
        (_) => (random.nextDouble() - 0.5) * 0.34,
      ),
      _shapeAxisBiasX = (random.nextDouble() - 0.5) * 0.06,
      _shapeAxisBiasY = (random.nextDouble() - 0.5) * 0.06,
      _shapeLobeBias = 0.02 + random.nextDouble() * 0.035,
      _shapeAngleOffset = random.nextDouble() * 2 * pi {
    currentShape = PebbleShape.fromTime(
      t: _shapeTimeOffset,
      staticBiases: _shapeStaticBiases,
      phaseOffsets: _shapePhaseOffsets,
      speedOffsets: _shapeSpeedOffsets,
      axisBiasX: _shapeAxisBiasX,
      axisBiasY: _shapeAxisBiasY,
      lobeBias: _shapeLobeBias,
      angleOffset: _shapeAngleOffset,
    );
  }

  /// 基于相对锚点将其放置到绝对物理坐标系中
  void placeAtAnchor(Size arenaSize) {
    center = Offset(
      spec.anchor.dx * arenaSize.width,
      spec.anchor.dy * arenaSize.height,
    );
    hasPosition = true;
    clampToBounds(arenaSize);
  }

  /// 简单的刚性边界约束
  void clampToBounds(Size arenaSize) {
    if (!hasPosition) return;
    final halfW = spec.width / 2;
    final halfH = spec.height / 2;
    center = Offset(
      center.dx.clamp(halfW, arenaSize.width - halfW),
      center.dy.clamp(halfH, arenaSize.height - halfH),
    );
  }

  /// 柔性边界约束：越界时产生一个向内的拉力而不是瞬间卡死，使反弹看起来更松弛自然。
  void softBound(Size arenaSize) {
    if (!hasPosition) return;
    final halfW = spec.width / 2;
    final halfH = spec.height / 2;

    double newX = center.dx;
    double newY = center.dy;

    const strength = 0.2;
    if (newX < halfW) newX += (halfW - newX) * strength;
    if (newX > arenaSize.width - halfW) {
      newX -= (newX - (arenaSize.width - halfW)) * strength;
    }

    if (newY < halfH) newY += (halfH - newY) * strength;
    if (newY > arenaSize.height - halfH) {
      newY -= (newY - (arenaSize.height - halfH)) * strength;
    }

    center = Offset(newX, newY);
  }

  /// 冻结动力学，用于外界强制干预或者动画暂停时
  void freeze() {
    velocity = Offset.zero;
    targetVelocity = Offset.zero;
  }

  /// 每帧驱动核心逻辑：更新方向、推演坐标、重新计算形变因子。
  bool advance(
    Duration now,
    double dt,
    Size arenaSize,
    Random random,
    double amplitude,
    double morphSpeedMultiplier,
    double driftSpeedMultiplier,
  ) {
    if (!hasPosition) return false;

    bool changed = false;
    final effectiveDriftSpeed = driftSpeedMultiplier.clamp(0.0, 4.0);

    // 处理自发游走逻辑
    if (spec.animatePosition && effectiveDriftSpeed > 0.0001) {
      if (now >= _nextSteerAt) {
        final angle = random.nextDouble() * 2 * pi;
        final speed =
            (_minSpeed + random.nextDouble() * (_maxSpeed - _minSpeed)) *
            effectiveDriftSpeed;
        targetVelocity = Offset(cos(angle), sin(angle)) * speed;

        // 位移速度提高后，如果方向切换节奏还保持原样，会变成“飞得快但转向发钝”。
        // 这里同步缩短换向间隔，让整体观感仍然像流体漂移，而不是滑块乱窜。
        final steerScale = effectiveDriftSpeed.clamp(0.6, 2.4);
        _nextSteerAt =
            now +
            Duration(
              milliseconds:
                  ((1500 + random.nextInt(2000)) / steerScale).round(),
            );
      }

      final randomJitterState = Offset(
        (random.nextDouble() - 0.5) * _jitterStrength * effectiveDriftSpeed,
        (random.nextDouble() - 0.5) * _jitterStrength * effectiveDriftSpeed,
      );

      velocity = Offset.lerp(
        velocity,
        targetVelocity + randomJitterState,
        _steerLerpPerSecond * dt,
      )!;

      final currentSpeed = velocity.distance;
      if (currentSpeed > _maxSpeed) {
        velocity = velocity / currentSpeed * _maxSpeed;
      }

      if (currentSpeed < _minSpeed * 0.45 && targetVelocity.distance > 0) {
        final tv = targetVelocity.distance;
        velocity += targetVelocity / tv * (_minSpeed * 0.28 * dt);
      }

      var nextCenter = center + velocity * dt;
      final minX = spec.width / 2;
      final maxX = arenaSize.width - minX;
      final minY = spec.height / 2;
      final maxY = arenaSize.height - minY;

      // 边缘弹性碰撞反射
      if (nextCenter.dx < minX) {
        nextCenter = Offset(minX, nextCenter.dy);
        velocity = Offset(velocity.dx.abs() * 0.88, velocity.dy);
      } else if (nextCenter.dx > maxX) {
        nextCenter = Offset(maxX, nextCenter.dy);
        velocity = Offset(-velocity.dx.abs() * 0.88, velocity.dy);
      }

      if (nextCenter.dy < minY) {
        nextCenter = Offset(nextCenter.dx, minY);
        velocity = Offset(velocity.dx, velocity.dy.abs() * 0.88);
      } else if (nextCenter.dy > maxY) {
        nextCenter = Offset(nextCenter.dx, maxY);
        velocity = Offset(velocity.dx, -velocity.dy.abs() * 0.88);
      }

      if ((nextCenter - center).distanceSquared > 0.001) {
        center = nextCenter;
        changed = true;
      }
    }
    if (spec.animatePosition && effectiveDriftSpeed <= 0.0001) {
      // 当外部明确把行走速度调为 0 时，需要快速收掉历史惯性，
      // 否则视觉上会像“参数已经关了，但卡片还在偷偷滑动”。
      velocity = Offset.lerp(velocity, Offset.zero, (8 * dt).clamp(0.0, 1.0))!;
    }

    // 更新当前帧的平滑形状（应用独立的 timeOffset 防止共振现象）
    final timeSec = (now.inMicroseconds / 1000000.0) + _shapeTimeOffset;
    currentShape = PebbleShape.fromTime(
      t: timeSec,
      amplitudeScale: amplitude,
      speedMultiplier: morphSpeedMultiplier,
      staticBiases: _shapeStaticBiases,
      phaseOffsets: _shapePhaseOffsets,
      speedOffsets: _shapeSpeedOffsets,
      axisBiasX: _shapeAxisBiasX,
      axisBiasY: _shapeAxisBiasY,
      lobeBias: _shapeLobeBias,
      angleOffset: _shapeAngleOffset,
    );
    // 形状由于是由时间驱动的绝对连续变量，因此强保更新帧。
    changed = true;

    return changed;
  }
}
