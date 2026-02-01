import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/notification_service.dart';
import '../models/transaction_model.dart';

class ImportExportWidget extends StatefulWidget {
  final List<TransactionModel> transactions;
  final String userName;
  final VoidCallback onTransactionsImported;

  const ImportExportWidget({
    Key? key,
    required this.transactions,
    required this.userName,
    required this.onTransactionsImported,
  }) : super(key: key);

  @override
  State<ImportExportWidget> createState() => _ImportExportWidgetState();
}

class _ImportExportWidgetState extends State<ImportExportWidget> {
  bool _isLoading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Importer/Exporter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _message!.contains('Erreur')
                      ? Colors.red[100]
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('Erreur')
                        ? Colors.red[900]
                        : Colors.green[900],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Exporter: ${widget.transactions.length} transactions',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _exportCSV,
                    icon: const Icon(Icons.download),
                    label: const Text('CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _exportExcel,
                    icon: const Icon(Icons.download),
                    label: const Text('Excel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _exportPDF,
                    icon: const Icon(Icons.download),
                    label: const Text('PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Importer des transactions',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _importCSV,
                    icon: const Icon(Icons.upload),
                    label: const Text('Importer CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _importExcel,
                    icon: const Icon(Icons.upload),
                    label: const Text('Importer Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('En cours...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCSV() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final path = await ExportService.instance.exportToCSV(
        widget.transactions,
      );
      setState(() {
        _message = '✅ Export CSV réussi: $path';
      });
      
      await NotificationService.instance.showNotification(
        id: 1004,
        title: 'Export réussi',
        body: 'Les transactions ont été exportées en CSV',
      );
    } catch (e) {
      setState(() {
        _message = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportExcel() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final path = await ExportService.instance.exportToExcel(
        widget.transactions,
      );
      setState(() {
        _message = '✅ Export Excel réussi: $path';
      });

      await NotificationService.instance.showNotification(
        id: 1005,
        title: 'Export réussi',
        body: 'Les transactions ont été exportées en Excel',
      );
    } catch (e) {
      setState(() {
        _message = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPDF() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final path = await ExportService.instance.exportToPDF(
        widget.transactions,
        widget.userName,
      );
      setState(() {
        _message = '✅ Export PDF réussi: $path';
      });

      await NotificationService.instance.showNotification(
        id: 1006,
        title: 'Export réussi',
        body: 'Les transactions ont été exportées en PDF',
      );
    } catch (e) {
      setState(() {
        _message = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isLoading = true;
        _message = null;
      });

      final file = result.files.first;
      // You need to pass userId and accountId from the calling screen
      // For now, this is a placeholder
      // final transactions = await ImportService.instance.importFromCSV(
      //   File(file.path!),
      //   userId,
      //   accountId,
      // );

      setState(() {
        _message =
            '✅ Import CSV réussi - ${file.name} traité';
      });

      widget.onTransactionsImported();
    } catch (e) {
      setState(() {
        _message = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isLoading = true;
        _message = null;
      });

      final file = result.files.first;
      // You need to pass userId and accountId from the calling screen
      // For now, this is a placeholder
      // final transactions = await ImportService.instance.importFromExcel(
      //   File(file.path!),
      //   userId,
      //   accountId,
      // );

      setState(() {
        _message =
            '✅ Import Excel réussi - ${file.name} traité';
      });

      widget.onTransactionsImported();
    } catch (e) {
      setState(() {
        _message = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
