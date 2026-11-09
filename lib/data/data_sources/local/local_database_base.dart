import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

abstract class LocalDatabaseBase extends GetxService {
  Future<Database> get database;
  String get currentUserId;
}
