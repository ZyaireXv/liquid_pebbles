import 'dart:math';

/// 基于时间的谐波平滑多边形生成器。
/// 这个类专门负责输出每一帧的半径缩放因子，让图形产生类似液体呼吸的舒缓律动感。
class PebbleShape {
  /// 多方向半径缩放因子（按顺时针排列）。
  /// 比如 factorCount 为 12 时，代表圆周上的 12 个等分点的半径偏移比例。
  final List<double> radialFactors;

  /// 当前形状在所有采样方向中的最大外扩系数。
  ///
  /// 碰撞检测不能只看参考宽高，因为液态形变后，真实轮廓会暂时鼓出去。
  /// 这里暴露最大系数，是为了让外部在“禁止重叠”模式下按真实外沿做分离，
  /// 否则就会出现明明设置了 gap，视觉上却还是蹭在一起的情况。
  double get maxRadialFactor {
    if (radialFactors.isEmpty) {
      return 1.0;
    }
    return radialFactors.reduce(max);
  }

  // 采样点数量。保持在 12 可以产生圆润的弧度，采样点过多边缘会显得过于锐利或突兀。
  static const int factorCount = 12;

  // 相位和频率偏移常数，确保每个角度的波形不一致，产生类似真实液滴受重力/张力拉扯的不规则感。
  static final List<double> _phases = List.generate(
    factorCount,
    (i) => i * 0.5,
  );

  static final List<double> _speeds = List.generate(
    factorCount,
    (i) => 0.8 + (i % 3) * 0.4,
  );

  const PebbleShape({required this.radialFactors});

  /// 将外部输入的形变强度压缩到一个可控区间内。
  ///
  /// 原因不是限制使用者，而是液态轮廓的感知并不是线性增长的：
  /// 当 amplitude 从 1 增加到 2 时，看起来是“更活”；但继续暴力放大到 10、15，
  /// 视觉结果就不再像液体，而会迅速滑向撕裂、尖刺和局部塌陷。
  /// 因此这里使用非线性映射，让低值区保留细腻调节能力，高值区自动趋于平缓。
  static double normalizeAmplitude(double amplitudeScale) {
    final safeAmplitude = amplitudeScale.isFinite ? amplitudeScale : 1.0;
    if (safeAmplitude <= 1.0) {
      return safeAmplitude.clamp(0.2, 1.0);
    }
    return (1.0 + log(safeAmplitude) * 0.48).clamp(1.0, 2.1);
  }

  /// 基于连续时间 [t] (秒) 生成形状。
  /// [amplitudeScale] 越大，卡片的形变挤压程度越夸张。
  /// [speedMultiplier] 越大，形变滚动的速度越快。
  factory PebbleShape.fromTime({
    required double t,
    double amplitudeScale = 1.0,
    double speedMultiplier = 1.0,
    List<double>? staticBiases,
    List<double>? phaseOffsets,
    List<double>? speedOffsets,
    double axisBiasX = 0.0,
    double axisBiasY = 0.0,
    double lobeBias = 0.0,
    double angleOffset = 0.0,
  }) {
    final effectiveAmplitude = normalizeAmplitude(amplitudeScale);
    return PebbleShape(
      radialFactors: List<double>.generate(factorCount, (i) {
        final angle = angleOffset + (2 * pi * i / factorCount);

        // 利用正弦和余弦的叠加，生成没有尖锐突刺的平滑低频噪波（类似简单的伪柏林噪声）
        final wave1 = sin(
          t *
                  ((_speeds[i] + (speedOffsets == null ? 0.0 : speedOffsets[i])) *
                      speedMultiplier) +
              _phases[i] +
              (phaseOffsets == null ? 0.0 : phaseOffsets[i]),
        );
        final wave2 = cos(
          t *
                  (((_speeds[i] * 0.8) +
                          (speedOffsets == null
                              ? 0.0
                              : speedOffsets[(i + 3) % factorCount] * 0.55)) *
                      speedMultiplier) +
              _phases[(i + 3) % factorCount] +
              (phaseOffsets == null ? 0.0 : phaseOffsets[(i + 5) % factorCount]),
        );

        // 归一化到 -1.0 ~ 1.0 之间
        final normalizedNoise = (wave1 + wave2) / 2.0;

        // 这里加入“固定形状偏置”，目的是给每个 Pebble 一个稳定但不规则的先天轮廓。
        // 如果所有节点都共享同一组基础谐波，它们总会周期性回到接近圆形/椭圆形的状态，
        // 看起来像数学模型而不像液体。
        final staticBias = staticBiases == null ? 0.0 : staticBiases[i];

        // 轴向偏置和瓣状偏置不会随时间消失，它们的作用是持续打破左右、上下、四象限的对称性，
        // 这样即使振幅较低，轮廓也仍然带一点“歪”和“扯”的感觉。
        final directionalBias =
            cos(angle) * axisBiasX +
            sin(angle) * axisBiasY +
            cos((angle * 3) + angleOffset * 1.7) * lobeBias;

        // 默认的基础变形幅度，在此基础上再乘以用户传入的缩放比例
        return (0.95 +
                (normalizedNoise * 0.12 * effectiveAmplitude) +
                staticBias +
                directionalBias)
            .clamp(0.74, 1.18);
      }),
    );
  }
}
