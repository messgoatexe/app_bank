import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';

class ImportService {
  ImportService._private();
  static final ImportService instance = ImportService._private();
  final _uuid = const Uuid();

  /// Import transactions from CSV file
  /// Expected format: Date,Type,Category,Amount,Description
  /// Date format: dd/MM/yyyy or dd/MM/yyyy HH:mm
  Future<List<TransactionModel>> importFromCSV(
    File file,
    String userId,
    String? accountId,
  ) async {
    try {
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) {
        throw Exception('Le fichier CSV est vide');
      }

      // Skip header row
      final dataRows = rows.sublist(1);
      final transactions = <TransactionModel>[];

      for (final row in dataRows) {
        if (row.length < 4) continue; // Skip invalid rows

        try {
          final dateStr = row[0]?.toString() ?? '';
          final type = row[1]?.toString() ?? '';
          final category = row[2]?.toString() ?? '';
          final amountStr = row[3]?.toString() ?? '0';
          final description = row.length > 4 ? row[4]?.toString() : null;

          if (dateStr.isEmpty || type.isEmpty || category.isEmpty) continue;

          // Parse date
          DateTime date;
          try {
            if (dateStr.contains(':')) {
              date = DateFormat('dd/MM/yyyy HH:mm').parse(dateStr);
            } else {
              date = DateFormat('dd/MM/yyyy').parse(dateStr);
            }
          } catch (e) {
            // Try other formats
            date = DateTime.parse(dateStr);
          }

          final amount = double.tryParse(amountStr) ?? 0.0;

          transactions.add(
            TransactionModel(
              id: _uuid.v4(),
              userId: userId,
              accountId: accountId,
              amount: amount,
              type: type,
              category: category,
              description: description,
              date: date,
            ),
          );
        } catch (e) {
          print('Erreur lors du parsing de la ligne: $e');
          continue;
        }
      }

      if (transactions.isEmpty) {
        throw Exception('Aucune transaction valide trouvée dans le fichier');
      }

      return transactions;
    } catch (e) {
      throw Exception('Erreur lors de l\'import CSV: $e');
    }
  }

  /// Import transactions from Excel file
  /// Expected columns: Date,Type,Category,Amount,Description
  Future<List<TransactionModel>> importFromExcel(
    File file,
    String userId,
    String? accountId,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.entries.first.value;

      if (sheet.rows.isEmpty) {
        throw Exception('Le fichier Excel est vide');
      }

      final transactions = <TransactionModel>[];

      // Skip header row
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        if (row.length < 4) continue;

        try {
          final dateCell = row[0]?.value?.toString() ?? '';
          final typeCell = row[1]?.value?.toString() ?? '';
          final categoryCell = row[2]?.value?.toString() ?? '';
          final amountCell = row[3]?.value?.toString() ?? '0';
          final descriptionCell =
              row.length > 4 ? row[4]?.value?.toString() : null;

          if (dateCell.isEmpty || typeCell.isEmpty || categoryCell.isEmpty) {
            continue;
          }

          // Parse date
          DateTime date;
          try {
            if (dateCell.contains(':')) {
              date = DateFormat('dd/MM/yyyy HH:mm').parse(dateCell);
            } else {
              date = DateFormat('dd/MM/yyyy').parse(dateCell);
            }
          } catch (e) {
            date = DateTime.parse(dateCell);
          }

          final amount = double.tryParse(amountCell) ?? 0.0;

          transactions.add(
            TransactionModel(
              id: _uuid.v4(),
              userId: userId,
              accountId: accountId,
              amount: amount,
              type: typeCell,
              category: categoryCell,
              description: descriptionCell,
              date: date,
            ),
          );
        } catch (e) {
          print('Erreur lors du parsing de la ligne $i: $e');
          continue;
        }
      }

      if (transactions.isEmpty) {
        throw Exception('Aucune transaction valide trouvée dans le fichier');
      }

      return transactions;
    } catch (e) {
      throw Exception('Erreur lors de l\'import Excel: $e');
    }
  }

  /// Validate imported transactions before saving
  List<TransactionModel> validateTransactions(
      List<TransactionModel> transactions) {
    return transactions.where((tx) {
      return tx.amount > 0 && tx.type.isNotEmpty && tx.category.isNotEmpty;
    }).toList();
  }
}
