import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';

class WalletRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  WalletRepository(this._appwrite);

  Future<List<WalletModel>> getWallets(String userId) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        queries: [Query.equal('ownerId', userId)],
      );
      return response.rows.map((row) => WalletModel.fromMap(row.data)).toList();
    });
  }

  Future<WalletModel> createWallet(
    String userId,
    String name,
    double initialBalance,
    String currency,
    String iconName,
    bool isDefault,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        rowId: ID.unique(),
        data: {
          'ownerId': userId,
          'name': name,
          'balance': initialBalance,
          'currency': currency,
          'iconName': iconName,
          'isDefault': isDefault,
        },
      );
      return WalletModel.fromMap(response.data);
    });
  }

  Future<WalletModel> updateWalletBalance(
    String walletId,
    double newBalance,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        rowId: walletId,
        data: {'balance': newBalance},
      );
      return WalletModel.fromMap(response.data);
    });
  }

  Future<void> deleteWallet(String walletId) async {
    return handleAppwriteError(() async {
      await _appwrite.tables.deleteRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        rowId: walletId,
      );
    });
  }
}
