import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_pebbles/liquid_pebbles.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const FluidPebbleDemoApp());
}

class FluidPebbleDemoApp extends StatelessWidget {
  const FluidPebbleDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Pebbles Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B4EE6)),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Liquid Pebbles Example',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          children: [
            _buildExampleBlock(
              title: 'No Overlap',
              subtitle: 'allowOverlap: false, minCardGap: 0',
              allowOverlap: false,
            ),
            const SizedBox(height: 28),
            _buildExampleBlock(
              title: 'Allow Overlap',
              subtitle: 'allowOverlap: true',
              allowOverlap: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleBlock({
    required String title,
    required String subtitle,
    required bool allowOverlap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LiquidPebbles(
            arenaHeight: 320.0,
            backgroundColor: Colors.white,
            // 两个示例的数据和视觉参数保持完全一致，只切换是否允许重叠，
            // 这样才能准确对比 overlap 策略本身的差异，而不是混入别的变量。
            amplitude: 1.2,
            driftSpeedMultiplier: 1.1,
            morphSpeedMultiplier: 1.45,
            minCardGap: 0,
            allowOverlap: allowOverlap,
            items: const [
              LiquidPebbleItem(
                baseColor: Color(0xFFFF9800),
                size: Size(132, 112),
                animatePosition:false,
                child: _DemoPebbleContent(
                  icon: Icons.favorite_rounded,
                  value: '45',
                  label: 'Resonance',
                ),
              ),
              LiquidPebbleItem(
                baseColor: Color(0xFF4CAF50),
                size: Size(112, 96),
                child: _DemoPebbleContent(
                  icon: Icons.edit_note_rounded,
                  value: '6',
                  label: 'Posts',
                ),
              ),
              LiquidPebbleItem(
                baseColor: Color(0xFF2196F3),
                size: Size(144, 120),
                child: _DemoPebbleContent(
                  icon: Icons.calendar_today_rounded,
                  value: '28',
                  label: 'Records',
                ),
              ),
              LiquidPebbleItem(
                baseColor: Color(0xFFE91E63),
                size: Size(112, 96),
                child: _DemoPebbleContent(
                  icon: Icons.bolt_rounded,
                  value: '12',
                  label: 'Streak',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoPebbleContent extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DemoPebbleContent({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
