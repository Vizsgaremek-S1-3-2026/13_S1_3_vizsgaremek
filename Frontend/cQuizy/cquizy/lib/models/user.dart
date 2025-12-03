class User {
  final int id;
  final String username;
  final bool isSuperuser;
  final String firstName;
  final String lastName;
  final String email;
  final bool isStaff;
  final bool isActive;
  final DateTime dateJoined;
  final String? nickname;
  final String? pfpUrl;

  User({
    required this.id,
    required this.username,
    required this.isSuperuser,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isStaff,
    required this.isActive,
    required this.dateJoined,
    this.nickname,
    this.pfpUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      isSuperuser: json['is_superuser'] ?? false,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      isStaff: json['is_staff'] ?? false,
      isActive: json['is_active'] ?? true,
      dateJoined: DateTime.parse(json['date_joined']),
      nickname: json['nickname'],
      pfpUrl: json['pfp_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'is_superuser': isSuperuser,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'is_staff': isStaff,
      'is_active': isActive,
      'date_joined': dateJoined.toIso8601String(),
      'nickname': nickname,
      'pfp_url': pfpUrl,
    };
  }

  User copyWith({
    int? id,
    String? username,
    bool? isSuperuser,
    String? firstName,
    String? lastName,
    String? email,
    bool? isStaff,
    bool? isActive,
    DateTime? dateJoined,
    String? nickname,
    String? pfpUrl,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      isStaff: isStaff ?? this.isStaff,
      isActive: isActive ?? this.isActive,
      dateJoined: dateJoined ?? this.dateJoined,
      nickname: nickname ?? this.nickname,
      pfpUrl: pfpUrl ?? this.pfpUrl,
    );
  }
}
