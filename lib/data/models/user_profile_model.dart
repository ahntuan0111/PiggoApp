class UserProfileModel {
  final String id;
  final String name;
  final String? email;
  final String? avatarPath;
  final String currencyCode;
  final String? pinHash;
  final bool isBiometricEnabled;
  final DateTime createdAt;

  /// Getter tương thích ngược với Appwrite User.$id
  String get $id => id;

  UserProfileModel({
    required this.id,
    this.name = 'Người dùng',
    this.email,
    this.avatarPath,
    this.currencyCode = 'VND',
    this.pinHash,
    this.isBiometricEnabled = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map['\$id'] ?? map['id'] ?? '',
      name: map['name'] ?? 'Người dùng',
      email: map['email'],
      avatarPath: map['avatarPath'],
      currencyCode: map['currencyCode'] ?? 'VND',
      pinHash: map['pinHash'],
      isBiometricEnabled:
          map['isBiometricEnabled'] == 1 || map['isBiometricEnabled'] == true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : (map['\$createdAt'] != null
              ? DateTime.tryParse(map['\$createdAt']) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarPath': avatarPath,
      'currencyCode': currencyCode,
      'pinHash': pinHash,
      'isBiometricEnabled': isBiometricEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarPath,
    String? currencyCode,
    String? pinHash,
    bool? isBiometricEnabled,
    DateTime? createdAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      currencyCode: currencyCode ?? this.currencyCode,
      pinHash: pinHash ?? this.pinHash,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
