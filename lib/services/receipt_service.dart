import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payment.dart';
import '../models/tenant.dart';
import '../models/unit.dart';

class ReceiptService {
  ReceiptService._();

  static final ReceiptService instance = ReceiptService._();

  Future<Uint8List> generateReceiptPdf({
    required PaymentRecord payment,
    required Unit unit,
    required Tenant? tenant,
    required double totalPaidThisMonth,
    required double remainingBalanceForMonth,
  }) async {
    final pdf = pw.Document();

    String fmtMoney(double value) => 'Ksh ${value.toStringAsFixed(2)}';

    final paymentDate = _fmtDate(payment.paymentDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Official Rent Receipt',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Receipt ID: ${payment.id}'),
              pw.SizedBox(height: 2),
              pw.Text('Unit: ${unit.unitNumber}'),
              pw.SizedBox(height: 2),
              pw.Text('Tenant: ${tenant?.name ?? 'N/A'}'),
              pw.SizedBox(height: 2),
              pw.Text('Method: ${payment.paymentMethod}'),
              pw.SizedBox(height: 18),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(90),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(90),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _tableCell('Date', bold: true),
                      _tableCell('Description', bold: true),
                      _tableCell('Reference', bold: true),
                      _tableCell('Amount', bold: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell(paymentDate),
                      _tableCell('Rent payment for Unit ${unit.unitNumber}'),
                      _tableCell(payment.transactionRef ?? '-'),
                      _tableCell(fmtMoney(payment.amountPaid)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Monthly Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text('Total Paid this Month: ${fmtMoney(totalPaidThisMonth)}'),
                    pw.Text('Remaining Balance: ${fmtMoney(remainingBalanceForMonth)}'),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.black),
              pw.SizedBox(height: 6),
              pw.Text(
                'Thank you for choosing Belmandy Housing.',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();

    // Persist a temporary copy for traceability/debugging before share flow.
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}receipt_${payment.id}.pdf');
    await file.writeAsBytes(bytes, flush: true);

    return bytes;
  }

  static pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  String _fmtDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
