import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plot_manager/core/theme.dart';

void main() {
  testWidgets('Midnight Slate themed app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(
            child: Text('Plot Manager Test Shell'),
          ),
        ),
      ),
    );

    expect(find.text('Plot Manager Test Shell'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
