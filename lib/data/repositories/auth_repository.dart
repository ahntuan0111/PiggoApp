import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart' as google;
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/exceptions.dart';
import 'package:appintern/core/utils/password_hasher.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/data/models/user_profile_model.dart';

import 'package:appintern/data/repositories/category_repository.dart';

/// Repository xác thực và quản lý tài khoản người dùng cục bộ (Local Auth Layer).
/// Lưu trữ hồ sơ người dùng trong bảng SQLite `user_profile`.
/// Hoàn toàn ngoại tuyến, bảo mật mật khẩu bằng PBKDF2-HMAC-SHA256 (128-bit Salt), hỗ trợ Google Sign-In độc lập.
class AuthRepository {
  final LocalDatabaseService _localDb = Get.find<LocalDatabaseService>();
  final StorageService _storage = Get.find<StorageService>();

  AuthRepository();

  /// Đăng ký tài khoản cục bộ với Username và Password
  Future<UserProfileModel> registerWithPassword({
    required String username,
    required String password,
    required String fullName,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanName = fullName.trim();

    if (cleanUsername.isEmpty) {
      throw ServerException("Tên đăng nhập không được để trống", 400, "empty_username");
    }
    if (cleanUsername.length < 3) {
      throw ServerException("Tên đăng nhập phải có ít nhất 3 ký tự", 400, "short_username");
    }
    if (cleanUsername.contains(' ') || !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(cleanUsername)) {
      throw ServerException("Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới, gạch ngang hoặc dấu chấm (không chứa khoảng trắng)", 400, "invalid_username");
    }
    if (cleanName.isEmpty) {
      throw ServerException("Họ và tên không được để trống", 400, "empty_name");
    }
    if (password.length < 6) {
      throw ServerException("Mật khẩu phải có ít nhất 6 ký tự để đảm bảo an toàn", 400, "weak_password");
    }

    final exists = await _localDb.userProfileExists(cleanUsername);
    if (exists) {
      throw ServerException("Tên đăng nhập đã tồn tại. Vui lòng chọn tên khác.", 409, "user_already_exists");
    }

    final passwordHash = PasswordHasher.hashPassword(password);
    final profile = UserProfileModel(
      id: cleanUsername,
      name: cleanName,
      email: '$cleanUsername@local',
      pinHash: passwordHash,
      createdAt: DateTime.now(),
    );

    await _localDb.saveUserProfile(profile);

    await _saveSession(profile);
    return profile;
  }

  /// Đăng nhập bằng Username và Password đã lưu trong SQLite
  Future<UserProfileModel> loginWithPassword({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || password.isEmpty) {
      throw ServerException("Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu", 400, "empty_fields");
    }

    final profile = await _localDb.getUserProfile(cleanUsername);
    if (profile == null) {
      throw ServerException("Tài khoản không tồn tại. Vui lòng kiểm tra lại hoặc đăng ký mới.", 404, "user_not_found");
    }

    final isPasswordValid = PasswordHasher.verifyPassword(password, profile.pinHash ?? '');
    if (!isPasswordValid) {
      throw ServerException("Mật khẩu không chính xác.", 401, "invalid_credentials");
    }

    // Tự động nâng cấp hash lên chuẩn PBKDF2 nếu tài khoản còn dùng hash cũ (SHA-256 thuần)
    if (profile.pinHash != null && !profile.pinHash!.startsWith('pbkdf2:sha256:')) {
      final upgradedHash = PasswordHasher.hashPassword(password);
      final updatedProfile = profile.copyWith(pinHash: upgradedHash);
      await _localDb.saveUserProfile(updatedProfile);
    }

    await _saveSession(profile);
    return profile;
  }

  /// Đăng nhập bằng Google (Thuần google_sign_in, không qua server trung gian)
  Future<UserProfileModel> loginWithGoogle() async {
    final google.GoogleSignIn googleSignIn = google.GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: '520092480732-g5mjid3nvkunl95pqttu9gj9uqe0g75j.apps.googleusercontent.com',
    );

    final google.GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } catch (e) {
      throw ServerException("Người dùng đã hủy đăng nhập Google hoặc xảy ra lỗi: $e", 400, "user_cancelled");
    }

    final String userId = account.id;
    final String name = account.displayName ?? 'Người dùng Google';
    final String email = account.email;
    final avatar = account.photoUrl;

    final existing = await _localDb.getUserProfile(userId);
    final profile = existing != null
        ? existing.copyWith(name: name, email: email, avatarPath: avatar)
        : UserProfileModel(
            id: userId,
            name: name,
            email: email,
            avatarPath: avatar,
            createdAt: DateTime.now(),
          );

    await _localDb.saveUserProfile(profile);
    await _saveSession(profile);
    return profile;
  }

  /// Lấy thông tin người dùng đang đăng nhập từ SQLite
  Future<UserProfileModel> getUser() async {
    final currentUserId = _storage.read<String>(AppKeys.userId);
    if (currentUserId == null || currentUserId.isEmpty) {
      throw ServerException("Chưa đăng nhập", 401, "unauthorized");
    }

    final profile = await _localDb.getUserProfile(currentUserId);
    if (profile == null) {
      throw ServerException("Không tìm thấy thông tin tài khoản", 401, "user_not_found");
    }

    return profile;
  }

  /// Đăng xuất khỏi ứng dụng
  Future<void> logout() async {
    _storage.remove(AppKeys.isLoggedIn);
    _storage.remove(AppKeys.userId);
    _storage.remove(AppKeys.userName);
    _storage.remove(AppKeys.avatarUrl);
    _storage.remove('userEmail');

    try {
      final google.GoogleSignIn googleSignIn = google.GoogleSignIn.instance;
      await googleSignIn.signOut().catchError((_) => null);
    } catch (_) {}
  }

  /// Xóa toàn bộ dữ liệu tài chính của người dùng
  Future<void> clearAllUserData([String? targetUserId]) async {
    if (targetUserId != null && targetUserId.isNotEmpty) {
      await _localDb.deleteUserProfile(targetUserId);
    }
    await _localDb.clearAllData();
    await logout();
  }

  /// Xóa vĩnh viễn tài khoản người dùng và hồ sơ khỏi SQLite
  Future<void> deleteUserAccount(String userId) async {
    await _localDb.deleteUserProfile(userId);
    await _localDb.clearAllData();
    await logout();
  }

  /// Lưu trạng thái đăng nhập vào StorageService và đảm bảo cách ly dữ liệu giữa các tài khoản
  Future<void> _saveSession(UserProfileModel profile) async {
    final String? lastActiveUserId = _storage.read<String>('lastActiveUserId');
    if (lastActiveUserId != null && lastActiveUserId.isNotEmpty && lastActiveUserId != profile.id) {
      // Khi phát hiện đổi tài khoản trên thiết bị: làm sạch dữ liệu cũ để tránh rò rỉ thông tin
      await _localDb.clearAllData();
      // Đảm bảo hồ sơ người dùng hiện tại luôn được lưu giữ an toàn trong SQLite
      await _localDb.saveUserProfile(profile);
      try {
        final categoryRepo = Get.find<CategoryRepository>();
        await categoryRepo.createDefaultCategoryTypes(profile.id);
      } catch (_) {}
    }
    _storage.write('lastActiveUserId', profile.id);

    _storage.write(AppKeys.isLoggedIn, true);
    _storage.write(AppKeys.userId, profile.id);
    _storage.write(AppKeys.userName, profile.name);
    if (profile.email != null) {
      _storage.write('userEmail', profile.email);
    }
    if (profile.avatarPath != null) {
      _storage.write(AppKeys.avatarUrl, profile.avatarPath);
    }
  }
}
