import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Lớp tiện ích băm và xác thực mật khẩu theo chuẩn mã hóa PBKDF2-HMAC-SHA256 với Salt.
/// 
/// Ngăn chặn:
/// 1. Tấn công Rainbow Table (bảng cầu vồng đã tính toán trước) nhờ Salt ngẫu nhiên 128-bit cho từng user.
/// 2. Tấn công vét cạn tốc độ cao (Brute-Force GPU) nhờ cơ chế Key Stretching với 10,000 vòng lặp.
/// 3. Tấn công Timing Attacks qua cơ chế Constant-Time Equality check.
class PasswordHasher {
  static const int defaultIterations = 10000;
  static const int saltBytesLength = 16; // 128-bit salt

  /// Sinh chuỗi Salt ngẫu nhiên bảo mật (Cryptographically Secure Random) dạng Hex
  static String generateSalt([int length = saltBytesLength]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Băm mật khẩu theo chuẩn PBKDF2-HMAC-SHA256 với Salt ngẫu nhiên
  /// Định dạng đầu ra: `pbkdf2:sha256:<iterations>:<saltHex>:<hashHex>`
  static String hashPassword(
    String password, {
    String? salt,
    int iterations = defaultIterations,
  }) {
    final effectiveSalt = salt ?? generateSalt();
    final saltBytes = _hexToBytes(effectiveSalt);

    final hmac = Hmac(sha256, utf8.encode(password));

    // U_1 = PRF(Password, Salt || INT_32_BE(1))
    final block1 = Uint8List(saltBytes.length + 4);
    block1.setRange(0, saltBytes.length, saltBytes);
    final byteData = ByteData.sublistView(block1, saltBytes.length);
    byteData.setUint32(0, 1, Endian.big);

    List<int> u = hmac.convert(block1).bytes;
    final result = List<int>.from(u);

    // Vòng lặp kéo dãn khóa: U_2 = PRF(P, U_1) ... U_c = PRF(P, U_{c-1})
    // F = U_1 ^ U_2 ^ ... ^ U_c
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    final hashHex = result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'pbkdf2:sha256:$iterations:$effectiveSalt:$hashHex';
  }

  /// Xác thực mật khẩu nhập vào so với chuỗi hash đã lưu trong CSDL
  /// Tương thích ngược: Nếu chuỗi hash cũ là SHA-256 thuần túy vẫn nhận diện được
  static bool verifyPassword(String password, String storedHash) {
    if (storedHash.isEmpty) return false;

    // Kiểm tra định dạng PBKDF2
    if (storedHash.startsWith('pbkdf2:sha256:')) {
      final parts = storedHash.split(':');
      if (parts.length != 5) return false;

      final iterations = int.tryParse(parts[2]) ?? defaultIterations;
      final salt = parts[3];
      final expectedHashHex = parts[4];

      final computedFullHash = hashPassword(
        password,
        salt: salt,
        iterations: iterations,
      );
      final computedParts = computedFullHash.split(':');
      if (computedParts.length != 5) return false;

      return _constantTimeEquals(computedParts[4], expectedHashHex);
    }

    // Tương thích ngược: SHA-256 thuần túy cũ (64 ký tự hex)
    final plainHash = sha256.convert(utf8.encode(password)).toString();
    return _constantTimeEquals(plainHash, storedHash);
  }

  /// So sánh hai chuỗi theo thời gian hằng số (Constant-time comparison)
  /// Tránh rò rỉ độ dài hoặc ký tự qua side-channel timing attack
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
