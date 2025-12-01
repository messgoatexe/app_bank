class UserModel {
  final String id;
  final String email;
  final String hashedPassword;
  final String? displayName;

  UserModel({
    required this.id,
    required this.email,
    required this.hashedPassword,
    this.displayName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'hashedPassword': hashedPassword,
        'displayName': displayName,
      };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id'] as String,
        email: m['email'] as String,
        hashedPassword: m['hashedPassword'] as String,
        displayName: m['displayName'] as String?,
      );
}
