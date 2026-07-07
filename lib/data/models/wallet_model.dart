class WalletModel {
  final String id;
  final String name;
  final double balance;
  final String currency;
  final String ownerId;
  final String iconName;
  final bool isDefault;

  WalletModel({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
    required this.ownerId,
    this.iconName = '📦', // Mặc định nếu không có
    this.isDefault = false,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['\$id'] ?? '',
      name: map['name'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'VND',
      ownerId: map['ownerId'] ?? '',
      iconName: map['iconName'] ?? '📦',
      isDefault: map['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'balance': balance,
      'currency': currency,
      'ownerId': ownerId,
      'iconName': iconName,
      'isDefault': isDefault,
    };
  }
}
