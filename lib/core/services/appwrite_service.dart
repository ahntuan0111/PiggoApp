import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

class AppwriteService extends GetxService {
  // Private instances to prevent direct modification
  late final Client _client;
  late final Databases _databases;
  late final TablesDB _tablesDB;
  late final Account _account;
  late final Functions _functions;

  late final Storage _storage;

  // Getters for read-only access
  Client get client => _client;
  Databases get databases => _databases;
  TablesDB get tables => _tablesDB;
  Account get account => _account;
  Functions get functions => _functions;
  Storage get storage => _storage;

  String get databaseId => dotenv.env['APPWRITE_DATABASE_ID']!;
  String get projectId => dotenv.env['APPWRITE_PROJECT_ID']!;
  String get avatarBucketId => dotenv.env['APPWRITE_AVATAR_BUCKET_ID'] ?? '';
  String get functionTransferBudget =>
      dotenv.env['APPWRITE_FUNCTION_TRANSFER_BUDGET']!;
  String get functionStatisticsInsight =>
      dotenv.env['APPWRITE_FUNCTION_STATISTICS_INSIGHT']!;
  String get functionGoogleSignIn =>
      dotenv.env['APPWRITE_FUNCTION_GOOGLE_SIGN_IN']!;
  String get functionParseTransaction =>
      dotenv.env['APPWRITE_FUNCTION_PARSE_TRANSACTION']!;
  String get functionParseReceiptVision =>
      dotenv.env['APPWRITE_FUNCTION_PARSE_RECEIPT_VISION']!;

  // Constants for table IDs
  final String categoriesTypeTableId = 'categorytypes';
  final String categoriesTableId = 'categories';
  final String monthlyBudgetsTableId = 'monthlybudgets';
  final String monthlySummariesTableId = 'monthlysummaries';
  final String transactionsTableId = 'transactions_';
  final String transactionDetailsTableId = 'transactiondetails';
  final String budgetshiStoryTableId = 'budgetshistory';
  final String goalsTableId = 'goals';
  final String transferLogsTableId = 'transferlogs';

  Future<AppwriteService> init() async {
    _client = Client();

    final endpoint = kIsWeb
        ? dotenv.env['APPWRITE_ENDPOINT_WEB']!
        : dotenv.env['APPWRITE_ENDPOINT_ANDROID']!;

    _client
        .setEndpoint(endpoint)
        .setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
        .setSelfSigned(status: true);

    _databases = Databases(_client);
    _tablesDB = TablesDB(_client);
    _account = Account(_client);
    _functions = Functions(_client);
    _storage = Storage(_client);

    debugPrint("🚀 Appwrite Service đã khởi tạo thành công tại: $endpoint");
    return this;
  }
}
