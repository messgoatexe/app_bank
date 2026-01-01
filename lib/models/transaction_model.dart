import 'package:intl/intl.dart';

class TransactionModel {
  final String id;
  final String userId; // Ajouter l'utilisateur
  final String? accountId; // Compte associé (optionnel)
  final double amount;
  final String type; // 'income' or 'expense'
  final String category;
  final String? description;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.userId,
    this.accountId,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'account_id': accountId,
        'amount': amount,
        'type': type,
        'category': category,
        'description': description,
        'date': date.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> m) => TransactionModel(
        id: m['id'] as String,
        userId: m['user_id'] as String? ?? '',
        accountId: m['account_id'] as String?,
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] as String,
        category: m['category'] as String,
        description: m['description'] as String?,
        date: DateTime.parse(m['date'] as String),
      );

  String get formattedDate => DateFormat.yMMMd().format(date);
}
