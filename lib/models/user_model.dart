class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? address;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.address,
    this.role = 'user',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      address: json['address'],
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'address': address,
      'role': role,
    };
  }
}

