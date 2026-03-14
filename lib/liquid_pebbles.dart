import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'pebble_clipper.dart';
import 'pebble_node_state.dart';

/// 暴露给外部装载小卡片的数据实体。
class LiquidPebbleItem {
  /// 卡片内要显示的实际内容 Widget
  final Widget child;

  /// 卡片的背景底色，会与环境底色形成融合。为了获得最佳显示效果，建议不要纯白或纯黑，带点灰度最佳。
  final Color baseColor;

  /// 单个卡片的参考尺寸。
  ///
  /// 这里使用“参考尺寸”而不是直接把视觉外框写死在组件内部，
  /// 是因为一旦抽成 package，外部页面对密度和层级的要求一定不同。
  /// 继续写死会让这个包只能复刻当前页面，失去复用价值。
  final Size size;

  /// 初始相对锚点，坐标范围为 0~1。
  ///
  /// 不传时由组件根据卡片数量给出一个相对均衡的默认排布。
  final Offset? anchor;

  /// 是否允许这张卡片参与随机游走。
  ///
  /// 抽成包之后需要保留静态卡片的能力，否则外部如果只想保留液态形变，
  /// 还得反过来改你的内部代码，这种 API 就不算完整。
  final bool animatePosition;

  const LiquidPebbleItem({
    required this.child,
    required this.baseColor,
    this.size = const Size(130, 90),
    this.anchor,
    this.animatePosition = true,
  });
}

/// 高级流体卡片游走组件 (Liquid Pebbles)。
/// 当需要展示一组有呼吸感、像液滴一样会自发游走和蠕变的统计信息卡片时使用。
class LiquidPebbles extends StatefulWidget {
  /// 数据源
  final List<LiquidPebbleItem> items;

  /// 组件整体环境背景底色
  final Color backgroundColor;

  /// 全局高度，组件宽度默认撑满占位
  final double arenaHeight;

  /// 用于粗略控制卡片碰撞和分离的内边距，使它们不过于紧缩
  final double minCardGap;

  /// 是否允许卡片互相重叠。
  ///
  /// 这和 `minCardGap` 不是一回事：
  /// `minCardGap` 表达的是“保持距离”，而 `allowOverlap` 表达的是“是否允许穿插”。
  /// 两者同时存在时，语义最清晰的做法是：只要允许重叠，就完全跳过 gap 约束，
  /// 否则外部很难判断当前到底是“软重叠”还是“严格分离”。
  final bool allowOverlap;

  /// 形变程度 (振幅)。默认 1.0；越大越容易扭曲夸张，调小则更接近正方形。
  final double amplitude;

  /// 行走速度倍率，只影响位置游走，不影响形变速度。
  ///
  /// 把它单独拆出来，是因为“轮廓蠕动”和“整体漂移”不是一回事。
  /// 如果继续共用同一个倍率，想让轮廓更活一点时，卡片也会被迫跑得更快，调参会很别扭。
  final double driftSpeedMultiplier;

  /// 蠕变速度倍率，只影响轮廓变化，不影响位置游走。
  final double morphSpeedMultiplier;

  /// 兼容旧版本的统一速度倍率。
  ///
  /// 老代码如果还在传这个值，就让它同时覆盖“行走速度”和“蠕变速度”，
  /// 这样不用一次性修改所有接入点；新代码则优先使用拆分后的两个参数。
  @Deprecated('Use driftSpeedMultiplier and morphSpeedMultiplier instead.')
  final double? speedMultiplier;

  /// 是否启用整体运动。
  ///
  /// 这个开关保留在组件层，而不是散落到每个节点里，是为了让外部接设置页时，
  /// 可以一处控制整个 Pebble 区域的动态表现。
  final bool motionEnabled;

  /// 外层承载区域的圆角。
  final double arenaBorderRadius;

  const LiquidPebbles({
    super.key,
    required this.items,
    required this.backgroundColor,
    this.arenaHeight = 256.0,
    this.minCardGap = 16.0,
    this.allowOverlap = false,
    this.amplitude = 1.0,
    this.driftSpeedMultiplier = 1.0,
    this.morphSpeedMultiplier = 1.0,
    @Deprecated('Use driftSpeedMultiplier and morphSpeedMultiplier instead.')
    this.speedMultiplier,
    this.motionEnabled = true,
    this.arenaBorderRadius = 24.0,
  });

  double get effectiveDriftSpeedMultiplier =>
      speedMultiplier ?? driftSpeedMultiplier;

  double get effectiveMorphSpeedMultiplier =>
      speedMultiplier ?? morphSpeedMultiplier;

  @override
  State<LiquidPebbles> createState() => _LiquidPebblesState();
}

class _LiquidPebblesState extends State<LiquidPebbles>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final Random _random = Random();

  late List<PebbleNodeState> _nodes;
  Duration _lastTick = Duration.zero;
  Size _arenaSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _initNodes();
    _ticker = createTicker(_onTick);
    if (widget.motionEnabled) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant LiquidPebbles oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_needsNodeRebuild(oldWidget)) {
      _initNodes();
      if (!_arenaSize.isEmpty) {
        _ensureArena(_arenaSize);
      }
    }

    if (oldWidget.motionEnabled != widget.motionEnabled) {
      _lastTick = Duration.zero;
      if (widget.motionEnabled) {
        if (!_ticker.isActive) {
          _ticker.start();
        }
      } else {
        _ticker.stop();
        for (final node in _nodes) {
          node.freeze();
        }
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  bool _needsNodeRebuild(LiquidPebbles oldWidget) {
    if (oldWidget.items.length != widget.items.length) {
      return true;
    }
    for (var index = 0; index < widget.items.length; index++) {
      final oldItem = oldWidget.items[index];
      final newItem = widget.items[index];
      if (oldItem.size != newItem.size ||
          oldItem.anchor != newItem.anchor ||
          oldItem.animatePosition != newItem.animatePosition) {
        return true;
      }
    }
    return false;
  }

  Offset _defaultAnchorForIndex(int index, int count) {
    if (count == 1) {
      return const Offset(0.5, 0.5);
    }
    if (count == 2) {
      return index == 0
          ? const Offset(0.32, 0.5)
          : const Offset(0.68, 0.5);
    }
    if (count == 3) {
      return const [
        Offset(0.28, 0.3),
        Offset(0.72, 0.34),
        Offset(0.5, 0.74),
      ][index];
    }
    if (count == 4) {
      return const [
        Offset(0.24, 0.22),
        Offset(0.78, 0.28),
        Offset(0.38, 0.72),
        Offset(0.74, 0.81),
      ][index];
    }

    // 超过四个时使用环形分布，是因为它比简单网格更适合这类带流动感的组件。
    // 规则网格会让整体看起来像 dashboard，不像有张力的液态簇。
    final angle = (index / count) * 2 * pi;
    return Offset(
      0.5 + 0.24 * cos(angle),
      0.5 + 0.24 * sin(angle),
    );
  }

  void _initNodes() {
    _nodes = List.generate(widget.items.length, (i) {
      final item = widget.items[i];
      final anchor = item.anchor ?? _defaultAnchorForIndex(i, widget.items.length);

      return PebbleNodeState(
        spec: PebbleCardSpec(
          width: item.size.width,
          height: item.size.height,
          anchor: anchor,
          animatePosition: item.animatePosition,
        ),
        random: _random,
      );
    });
  }

  void _ensureArena(Size size) {
    if (_arenaSize == size) {
      return;
    }
    _arenaSize = size;
    for (final node in _nodes) {
      if (!node.hasPosition) {
        node.placeAtAnchor(size);
      } else {
        node.clampToBounds(size);
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (_arenaSize.isEmpty || !widget.motionEnabled) {
      return;
    }
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed.inMicroseconds - _lastTick.inMicroseconds) / 1000000.0;
    _lastTick = elapsed;

    if (dt > 0.05 || !mounted) return;
    bool needsRepaint = false;

    for (final node in _nodes) {
      if (!node.hasPosition) {
        node.placeAtAnchor(_arenaSize);
      }
      final changed = node.advance(
        elapsed,
        dt,
        _arenaSize,
        _random,
        widget.amplitude,
        widget.effectiveMorphSpeedMultiplier,
        widget.effectiveDriftSpeedMultiplier,
      );
      if (changed) needsRepaint = true;
    }

    if (!widget.allowOverlap && _nodes.length > 1) {
      for (var pass = 0; pass < 3; pass++) {
        for (var i = 0; i < _nodes.length; i++) {
          for (var j = i + 1; j < _nodes.length; j++) {
            needsRepaint |= _separateNodes(_nodes[i], _nodes[j]);
          }
        }
      }
    }

    if (needsRepaint) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.arenaHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _ensureArena(Size(constraints.maxWidth, widget.arenaHeight));

          return Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.arenaBorderRadius),
            ),
            child: RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ..._nodes.asMap().entries.where((e) => e.value.hasPosition).map((
                    entry,
                  ) {
                    final node = entry.value;
                    final itemParams = widget.items[entry.key];

                    return Positioned(
                      left: node.center.dx - node.spec.width / 2,
                      top: node.center.dy - node.spec.height / 2,
                      width: node.spec.width,
                      height: node.spec.height,
                      child: PhysicalShape(
                        clipper: PebbleClipper(node.currentShape),
                        color: itemParams.baseColor,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        child: itemParams.child,
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _separateNodes(PebbleNodeState first, PebbleNodeState second) {
    var delta = second.center - first.center;
    var distSq = delta.distanceSquared;

    // 当两个中心几乎重合时，必须人工给一个方向。
    // 否则归一化方向向量会失效，碰撞分离也就退化成“知道重叠但推不开”。
    if (distSq <= 0.0001) {
      final angle = _random.nextDouble() * pi * 2;
      delta = Offset(cos(angle), sin(angle));
      distSq = 1.0;
    }

    final dist = sqrt(distSq);
    final direction = delta / dist;

    final firstRadius = _collisionRadius(first);
    final secondRadius = _collisionRadius(second);
    final gap = widget.minCardGap <= 0 ? 0.0 : widget.minCardGap;
    final minDistance = firstRadius + secondRadius + gap;

    if (dist >= minDistance) {
      return false;
    }

    final overlap = minDistance - dist;
    final halfPush = direction * (overlap / 2);
    first.center -= halfPush;
    second.center += halfPush;
    first.clampToBounds(_arenaSize);
    second.clampToBounds(_arenaSize);

    // 分离后顺手削掉一部分对向速度，避免下一帧又立刻撞回去，导致边缘持续打架。
    final relativeVelocity = second.velocity - first.velocity;
    final approachSpeed =
        relativeVelocity.dx * direction.dx + relativeVelocity.dy * direction.dy;
    if (approachSpeed < 0) {
      final correction = direction * (approachSpeed * 0.5);
      first.velocity += correction;
      second.velocity -= correction;
    }
    return true;
  }

  double _collisionRadius(PebbleNodeState node) {
    final halfWidth = node.spec.width / 2;
    final halfHeight = node.spec.height / 2;
    final shapeFactor = node.currentShape.maxRadialFactor;

    // 这里不能直接取 max(width, height) / 2 去做碰撞半径，
    // 因为那相当于按“外接圆”在分离，会天然偏保守。
    // 用户把 gap 设成 0 时，预期应该是“差不多刚好碰到”，
    // 而不是仍然隔着一圈看得见的空气。
    //
    // 改成几何均值之后，碰撞代理会更接近这类鹅卵石卡片的真实外沿，
    // 对长宽不完全一致的卡片尤其更自然。
    final baseRadius = sqrt(halfWidth * halfHeight);

    // 当 gap 为 0 时，再轻微收一点碰撞代理半径，
    // 让视觉结果更接近“贴边接触”而不是“看起来还没碰到”。
    final zeroGapTightening = widget.minCardGap <= 0 ? 0.96 : 1.0;
    return baseRadius * shapeFactor * zeroGapTightening;
  }
}
