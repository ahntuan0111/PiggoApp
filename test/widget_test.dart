import 'package:flutter_test/flutter_test.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/transaction_model.dart';

void main() {
  group('Local Data Models Tests', () {
    test('CategoryModel correctly converts toMap and fromMap for SQLite', () {
      final category = CategoryModel(
        id: 'cat_food_01',
        categoryTypeId: 'ct_essential',
        name: 'Ăn uống',
        iconName: 'fastfood',
        color: '#FF5722',
        defaultBudget: 3000000,
        targetAmount: 0,
        isActive: true,
      );

      final map = category.toMap();
      expect(map['id'], equals('cat_food_01'));
      expect(map['categoryTypeId'], equals('ct_essential'));
      expect(map['name'], equals('Ăn uống'));
      expect(map['isActive'], isTrue);

      final restored = CategoryModel.fromMap(map);
      expect(restored.id, equals(category.id));
      expect(restored.name, equals(category.name));
      expect(restored.isActive, isTrue);
    });

    test('TransactionModel correctly converts toMap and fromMap for SQLite', () {
      final txDate = DateTime(2026, 10, 26, 12, 30);
      final tx = TransactionModel(
        id: 'tx_local_123',
        amount: 45000.0,
        type: 'EXPENSE',
        categoryId: 'cat_food_01',
        transactionDate: txDate,
        status: 'COMPLETED',
        note: 'Cà phê sáng',
      );

      final map = tx.toMap();
      expect(map['id'], equals('tx_local_123'));
      expect(map['amount'], equals(45000.0));
      expect(map['type'], equals('EXPENSE'));
      expect(map['status'], equals('COMPLETED'));
      expect(map['note'], equals('Cà phê sáng'));

      final restored = TransactionModel.fromMap(map);
      expect(restored.id, equals(tx.id));
      expect(restored.note, equals('Cà phê sáng'));
    });

    test('TransactionModel handles empty categoryId (wallet adjustment / unallocated) properly', () {
      final tx = TransactionModel(
        id: 'tx_wallet_adj_1',
        amount: 500000.0,
        type: 'INCOME',
        categoryId: '',
        transactionDate: DateTime(2026, 10, 27),
        status: 'COMPLETED',
        note: 'Điều chỉnh số dư ban đầu',
      );

      final map = tx.toMap();
      expect(map.containsKey('categoryId'), isFalse);

      final restored = TransactionModel.fromMap({
        'id': 'tx_wallet_adj_1',
        'categoryId': null, // SQLite null value
        'amount': 500000.0,
        'type': 'INCOME',
        'transactionDate': '2026-10-27T00:00:00.000',
        'status': 'COMPLETED',
      });
      expect(restored.categoryId, equals(''));
      expect(restored.amount, equals(500000.0));
      expect(restored.type, equals('INCOME'));
    });
  });
}
