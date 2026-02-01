import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction_model.dart';

class ExportService {
  ExportService._private();
  static final ExportService instance = ExportService._private();

  /// Export transactions to CSV
  Future<String> exportToCSV(List<TransactionModel> transactions) async {
    try {
      final List<List<dynamic>> csvData = [
        ['ID', 'Date', 'Type', 'Category', 'Amount', 'Description']
      ];

      for (var tx in transactions) {
        csvData.add([
          tx.id,
          DateFormat('dd/MM/yyyy HH:mm').format(tx.date),
          tx.type,
          tx.category,
          tx.amount.toStringAsFixed(2),
          tx.description ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(csvData);

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'transactions_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      return file.path;
    } catch (e) {
      throw Exception('Erreur lors de l\'export CSV: $e');
    }
  }

  /// Export transactions to Excel
  Future<String> exportToExcel(List<TransactionModel> transactions) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];

      // Add headers
      sheet.appendRow([
        'ID',
        'Date',
        'Type',
        'Category',
        'Amount',
        'Description',
      ]);

      // Add data
      for (var tx in transactions) {
        sheet.appendRow([
          tx.id,
          DateFormat('dd/MM/yyyy HH:mm').format(tx.date),
          tx.type,
          tx.category,
          tx.amount,
          tx.description ?? '',
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'transactions_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);

      return file.path;
    } catch (e) {
      throw Exception('Erreur lors de l\'export Excel: $e');
    }
  }

  /// Export transactions to PDF
  Future<String> exportToPDF(
    List<TransactionModel> transactions,
    String userName,
  ) async {
    try {
      final pdf = pw.Document();

      // Group transactions by date
      final Map<String, List<TransactionModel>> groupedTx = {};
      for (var tx in transactions) {
        final dateKey = DateFormat('dd/MM/yyyy').format(tx.date);
        groupedTx.putIfAbsent(dateKey, () => []);
        groupedTx[dateKey]!.add(tx);
      }

      final sortedDates = groupedTx.keys.toList()..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

      // Create PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            final widgets = <pw.Widget>[
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Rapport des Transactions',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Utilisateur: $userName',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Généré le: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
            ];

            for (final date in sortedDates) {
              final txList = groupedTx[date]!;
              final dayTotal =
                  txList.fold<double>(0, (sum, tx) => sum + tx.amount);

              widgets.add(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      date,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      children: [
                        // Headers
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey300),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Heure',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Type',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Catégorie',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Montant',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Description',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        // Transactions
                        ...txList.map((tx) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  DateFormat('HH:mm').format(tx.date),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(tx.type),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(tx.category),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  '${tx.amount.toStringAsFixed(2)} €',
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(tx.description ?? '-'),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Total du jour: ${dayTotal.toStringAsFixed(2)} €',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 16),
                  ],
                ),
              );
            }

            // Add total
            final total =
                transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
            widgets.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Total général: ${total.toStringAsFixed(2)} €',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );

            return widgets;
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'transactions_${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      throw Exception('Erreur lors de l\'export PDF: $e');
    }
  }
}
