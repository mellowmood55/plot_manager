import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:plot_manager/features/maintenance/screens/maintenance_detail_screen.dart';
import 'package:plot_manager/models/contractor.dart';
import 'package:plot_manager/models/maintenance_request.dart';

class MockMaintenanceDetailDataSource extends Mock
    implements MaintenanceDetailDataSource {}

void main() {
  late MockMaintenanceDetailDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockMaintenanceDetailDataSource();
  });

  MaintenanceRequest buildRequestWithContractor() {
    return MaintenanceRequest(
      id: 'req-1',
      unitId: 'unit-1',
      title: 'Broken Window',
      description: 'Window pane cracked after storm',
      category: 'Repairs',
      priority: MaintenancePriority.medium,
      status: MaintenanceStatus.open,
      estimatedCost: 2500,
      actualCost: null,
      imageUrl: null,
      afterImageUrl: null,
      resolvedAt: null,
      contractorId: 'cont-1',
      contractor: Contractor(
        id: 'cont-1',
        name: 'Alex Fixer',
        phone: '0712345678',
        specialty: 'General Handyman',
      ),
      createdAt: DateTime(2026, 4, 4),
      updatedAt: DateTime(2026, 4, 4),
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: child,
    );
  }

  testWidgets(
      'shows Call Contractor button when contractor is assigned',
      (tester) async {
    when(() => mockDataSource.getMaintenanceRequestById(any()))
        .thenAnswer((_) async => buildRequestWithContractor());

    await tester.pumpWidget(
      wrap(
        MaintenanceDetailScreen(
          requestId: 'req-1',
          dataSource: mockDataSource,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Call Contractor'), findsOneWidget);
  });

  testWidgets('Mark as Resolved opens the resolution dialog',
      (tester) async {
    when(() => mockDataSource.getMaintenanceRequestById(any()))
        .thenAnswer((_) async => buildRequestWithContractor());

    await tester.pumpWidget(
      wrap(
        MaintenanceDetailScreen(
          requestId: 'req-1',
          dataSource: mockDataSource,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final resolveButton = find.text('Mark as Resolved');
    expect(resolveButton, findsOneWidget);

    await tester.tap(resolveButton);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Resolution'), findsOneWidget);
  });
}
