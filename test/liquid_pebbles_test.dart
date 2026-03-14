import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:liquid_pebbles/liquid_pebbles.dart';

void main() {
  testWidgets('renders pebble children', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidPebbles(
            backgroundColor: Colors.white,
            items: const [
              LiquidPebbleItem(
                baseColor: Colors.blue,
                child: Center(child: Text('A')),
              ),
              LiquidPebbleItem(
                baseColor: Colors.green,
                child: Center(child: Text('B')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
