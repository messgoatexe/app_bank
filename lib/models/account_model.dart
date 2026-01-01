class AccountModel {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final String currency;
  final DateTime createdAt;

  AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    this.currency = 'EUR',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'balance': balance,
        'currency': currency,
        'created_at': createdAt.toIso8601String(),
      };

  factory AccountModel.fromMap(Map<String, dynamic> m) => AccountModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        balance: (m['balance'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'EUR',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
