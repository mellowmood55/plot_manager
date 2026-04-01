import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plot_manager/widgets/specialty_dropdown_field.dart';

void main() {
  group('SpecialtyDropdownField', () {
    testWidgets('renders as dropdown form field', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialtyDropdownField(controller: controller),
          ),
        ),
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Specialty'), findsOneWidget);
    });

    testWidgets('sets default value to General Handyman', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialtyDropdownField(controller: controller),
          ),
        ),
      );

      expect(controller.text, 'General Handyman');
    });

    testWidgets('keeps pre-filled custom specialty as selected value', (tester) async {
      final controller = TextEditingController(text: 'Plumber Pro');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialtyDropdownField(controller: controller),
          ),
        ),
      );

      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );

      expect(field.initialValue, 'Plumber Pro');
    });

    testWidgets('syncs controller and callback when value changes', (tester) async {
      final controller = TextEditingController();
      String? changed;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialtyDropdownField(
              controller: controller,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );

      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );

      field.onChanged?.call('Plumbing');
      await tester.pump();

      expect(controller.text, 'Plumbing');
      expect(changed, 'Plumbing');
    });

    testWidgets('uses fallback validator when no validator provided', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: SpecialtyDropdownField(controller: controller),
            ),
          ),
        ),
      );

      final valid = formKey.currentState!.validate();
      expect(valid, true);
    });
  });
}
