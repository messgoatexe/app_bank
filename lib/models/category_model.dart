class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String type; // 'income' or 'expense'
  final String? color;
  final String? icon;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.color,
    this.icon,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'type': type,
        'color': color,
        'icon': icon,
        'created_at': createdAt.toIso8601String(),
      };

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        color: m['color'] as String?,
        icon: m['icon'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
