class User {
  final bool isSuperuser;
  final String firstName;
  final String lastName;
  final String email;
  final bool isStaff;
  final bool isActive;
  final DateTime dateJoined;
  final String? nickname;

  User({
    required this.isSuperuser,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isStaff,
    required this.isActive,
    required this.dateJoined,
    this.nickname,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      isSuperuser: json['is_superuser'] ?? false,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      isStaff: json['is_staff'] ?? false,
      isActive: json['is_active'] ?? true,
      dateJoined: DateTime.parse(json['date_joined']),
      nickname: json['nickname'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_superuser': isSuperuser,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'is_staff': isStaff,
      'is_active': isActive,
      'date_joined': dateJoined.toIso8601String(),
      'nickname': nickname,
    };
  }

  User copyWith({
    bool? isSuperuser,
    String? firstName,
    String? lastName,
    String? email,
    bool? isStaff,
    bool? isActive,
    DateTime? dateJoined,
    String? nickname,
  }) {
    return User(
      isSuperuser: isSuperuser ?? this.isSuperuser,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      isStaff: isStaff ?? this.isStaff,
      isActive: isActive ?? this.isActive,
      dateJoined: dateJoined ?? this.dateJoined,
      nickname: nickname ?? this.nickname,
    );
  }
}
