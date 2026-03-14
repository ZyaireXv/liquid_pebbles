import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('example app boots successfully', (tester) async {
    await tester.pumpWidget(const FluidPebbleDemoApp());
    await tester.pump();

    expect(find.text('Liquid Pebbles Example'), findsOneWidget);
  });
}
