import 'package:flutter_test/flutter_test.dart';

import 'package:plot_manager/services/finance_service.dart';
import 'package:plot_manager/services/payment_service.dart';

void main() {
  group('Finance logic tests', () {
    test('Net Profit = Total Revenue - Total Expenses', () {
      final service = FinanceService.instance;

      final result = service.calculateNetProfit(
        totalRevenue: 150000,
        totalExpenses: 42000,
      );

      expect(result, 108000);
    });

    test('MRI tax 10% is accurate for multiple income levels', () {
      final service = FinanceService.instance;
      const levels = <double>[0, 1000, 12500.50, 50000, 999999.99];

      for (final income in levels) {
        final tax = service.calculateMriTax(income);
        expect(tax, closeTo(income * 0.10, 0.0001));
      }
    });

    test('M-Pesa parser extracts amount and transaction code safely', () {
      const smsSamples = <String>[
        'QK12AB34CD Confirmed. Ksh1,500.00 sent to John Doe on 04/04/2026.',
        'confirmed: tx XK9LMN8PQR. ksh 750.00 paid on 1/3/26',
        'No structured values here, parser should not crash.',
        'RTYUIOP123 confirmed Ksh 20. received on 12/12/2025',
      ];

      for (final sms in smsSamples) {
        expect(() => PaymentService.parseMpesaSms(sms), returnsNormally);
      }

      final parsed1 = PaymentService.parseMpesaSms(smsSamples[0]);
      expect(parsed1.transactionCode, 'QK12AB34CD');
      expect(parsed1.amount, 1500.00);

      final parsed2 = PaymentService.parseMpesaSms(smsSamples[1]);
      expect(parsed2.transactionCode, 'XK9LMN8PQR');
      expect(parsed2.amount, 750.00);

      final parsed3 = PaymentService.parseMpesaSms(smsSamples[2]);
      expect(parsed3.amount, isNull);
      expect(parsed3.hasMatch, isTrue);
    });
  });
}
