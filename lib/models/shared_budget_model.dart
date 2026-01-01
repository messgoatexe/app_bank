class SharedBudgetModel {
  final String id;
  final String name;
  final double monthlyLimit;
  final List<String> userIds; // Users who share this budget
  final String? description;
  final DateTime createdAt;

  SharedBudgetModel({
    required this.id,
    required this.name,
    required this.monthlyLimit,
    required this.userIds,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'monthly_limit': monthlyLimit,
        'user_ids': userIds.join(','),
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };

  factory SharedBudgetModel.fromMap(Map<String, dynamic> m) =>
      SharedBudgetModel(
        id: m['id'] as String,
        name: m['name'] as String,
        monthlyLimit: (m['monthly_limit'] as num).toDouble(),
        userIds: (m['user_ids'] as String).split(','),
        description: m['description'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class BudgetMemberModel {
  final String budgetId;
  final String userId;
  final String role; // 'owner' or 'member'
  final DateTime joinedAt;

  BudgetMemberModel({
    required this.budgetId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'budget_id': budgetId,
        'user_id': userId,
        'role': role,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory BudgetMemberModel.fromMap(Map<String, dynamic> m) =>
      BudgetMemberModel(
        budgetId: m['budget_id'] as String,
        userId: m['user_id'] as String,
        role: m['role'] as String,
        joinedAt: DateTime.parse(m['joined_at'] as String),
      );
}
