# liquid_pebbles

`liquid_pebbles` 是一个纯 Flutter 实现的 UI 组件库，用于构建具有缓慢游走、持续蠕变效果的沉浸式“鹅卵石”卡片容器。

该组件在视觉上呈现出类似液滴或细胞的生命力特征，非常适合应用于个人中心统计、数据概览面板或首页的 Hero 区域。它能在不干扰核心信息阅读的前提下，为界面提供克制而灵动的动态背景。由于完全基于 Dart 和 Flutter 绘制，该包没有任何底层平台依赖，可以无缝接入各端项目。

## 效果预览

![liquid_pebbles 演示](doc/images/liquid_pebbles_demo.gif)

## 核心特性

- **多卡片同台展示**：支持在同一区域内容纳多个流体卡片。
- **独立状态控制**：每张卡片均可独立设置初始参考尺寸、停靠锚点以及是否参与游走。
- **多维度速度调节**：支持将“位置漂移”与“轮廓蠕变”的速度拆分离散控制。
- **碰撞与重叠策略**：提供灵活的碰撞边界检测，并允许通过 `minCardGap` 精确控制卡片间的安全距离，或直接开启无视碰撞的重叠模式。
- **有机形状生成**：基于谐波叠加的形状生成算法，确保轮廓时刻变化且不会退化为生硬的几何图形。
- **开箱即用**：不包含特定的业务逻辑或冗杂的资源文件，是一个纯粹的排版与视觉容器。

## 适用场景

- 个人中心的用户数据与成就展示
- 健康、心理或习惯养成类应用的数据概览板
- 需要打破传统网格排版，追求有机视觉体验的轻交互信息区

*(注：如果你的业务场景需要严格对齐的栅格排版或高密度的数据呈现，建议使用常规的列表或网格组件。)*

## 安装指南

在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  liquid_pebbles: ^0.0.1
```

随后在终端执行：

```bash
flutter pub get
```

## 快速上手

以下是一段最小化的接入代码，展示了如何在页面中嵌入该组件：

```dart
import 'package:flutter/material.dart';
import 'package:liquid_pebbles/liquid_pebbles.dart';

class DemoSection extends StatelessWidget {
  const DemoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidPebbles(
      arenaHeight: 300,
      backgroundColor: const Color(0xFFF4F7FB),
      amplitude: 1.2,
      driftSpeedMultiplier: 0.9,
      morphSpeedMultiplier: 1.3,
      minCardGap: 8,
      allowOverlap: false,
      items: const [
        LiquidPebbleItem(
          baseColor: Color(0xFFFF9800),
          size: Size(132, 112),
          child: Center(child: Text('45')),
        ),
        LiquidPebbleItem(
          baseColor: Color(0xFF4CAF50),
          size: Size(112, 96),
          child: Center(child: Text('6')),
        ),
        LiquidPebbleItem(
          baseColor: Color(0xFF2196F3),
          size: Size(144, 120),
          child: Center(child: Text('28')),
        ),
      ],
    );
  }
}
```

## 详细参数说明

### `LiquidPebbles` (容器层)

- **`items`**  
  卡片数据源，接收一组 `LiquidPebbleItem`。
- **`backgroundColor`**  
  舞台背景色。为凸显卡片的液态质感，建议采用与页面主体融合的低饱和或浅色背景。
- **`arenaHeight`**  
  组件的固定高度。宽度默认撑满父级约束。
- **`minCardGap`**  
  卡片安全间距。仅在 `allowOverlap` 为 `false` 时生效。如果设为 `0`，卡片会呈现出边缘碰触的视觉状态。
- **`allowOverlap`**  
  是否允许卡片物理重叠。开启后将完全忽略 `minCardGap` 的碰撞检测。
- **`amplitude`**  
  形变振幅，决定鹅卵石边缘扭曲的夸张程度。
  - `0.8 ~ 1.5`：呈现微弱的呼吸感。
  - `1.5 ~ 3.0`：明显的液态张力，富有活力。
  - `3.0+`：高度扭曲，适合概念性或实验性表达。
- **`driftSpeedMultiplier`**  
  漂移速度乘数，专门控制卡片在舞台中相互碰撞游走的快慢。
- **`morphSpeedMultiplier`**  
  蠕变速度乘数，专门控制卡片边缘不规则变形的频率。
- **`motionEnabled`**  
  全局动画开关。设为 `false` 可暂停所有的位置移动与形状变形，常用于应用退到后台或页面被遮挡时节省性能。
- **`arenaBorderRadius`**  
  组件外部容器的圆角大小。

### `LiquidPebbleItem` (卡片层)

- **`child`**  
  卡片内部承载的业务元素（如文本、图标）。
- **`baseColor`**  
  卡片的底色材质。
- **`size`**  
  单张卡片的基准物理尺寸。组件在运行时会针对这一基准区域进行非破坏性的形状扭曲。
- **`anchor`**  
  初始化时的停靠坐标（比例范围 `0~1`）。如果为空，组件会根据卡片数量自动分配一个视觉均衡的初始展位。
- **`animatePosition`**  
  游走开关。如果希望该卡片只在原地进行形状蠕动而不产生位移，可将其置为 `false`。

## 视觉风格配置参考

该组件对参数极为敏感，你可以通过微调各向数值来适配不同应用的气质：

**内敛与舒缓**  
适用于日记、健康等需要情绪稳定的应用场景，卡片相互保持距离且缓缓呼吸。
```dart
amplitude: 1.0,
driftSpeedMultiplier: 0.6,
morphSpeedMultiplier: 1.0,
allowOverlap: false,
minCardGap: 8,
```

**灵动与活泼**  
适用于社交、宠物或运动成就展示，卡片变形更显著，游走更频繁。
```dart
amplitude: 1.8,
driftSpeedMultiplier: 1.1,
morphSpeedMultiplier: 1.5,
allowOverlap: false,
minCardGap: 4,
```

**前卫与解构**  
允许元素穿插，边缘呈现强烈的无序流体特征，适合个性强烈的设计表达。
```dart
amplitude: 2.6,
driftSpeedMultiplier: 1.4,
morphSpeedMultiplier: 1.8,
allowOverlap: true,
```

## 工程源码结构

插件的核心代码组织如下：
- `lib/liquid_pebbles.dart`: 对外暴露的 API 入口与容器级的生命周期、碰撞和重绘调度。
- `lib/pebble_node_state.dart`: 处理单体卡片的物理运动追踪、速度阻尼及包围盒碰撞缓冲。
- `lib/pebble_shape.dart`: 底层形状演算引擎，利用多相位谐波为每一帧产出连续且不重样的平滑因子。
- `lib/pebble_clipper.dart`: 负责将演算后的流体坐标路径真正转译为 Flutter 的贝塞尔剪切蒙版。

## 示例项目

你可以通过运行插件自带的 `example/` 工程来实际感受各项参数的物理表现。示例工程内置了分离排列和允许重叠的两种经典演示。

```bash
cd example
flutter run
```
