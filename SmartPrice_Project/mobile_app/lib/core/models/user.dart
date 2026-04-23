/// Model đại diện cho tài khoản người dùng.
class User {
  final String id;
  final String name;
  final String email;
  final bool isAdmin;
  final bool isActive;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.isAdmin = false,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['_id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        'isAdmin': isAdmin,
        'isActive': isActive,
      };
}
