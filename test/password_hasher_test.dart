import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:appintern/core/utils/password_hasher.dart';

void main() {
  group('PasswordHasher Tests', () {
    test('generateSalt generates 32 hex chars (16 bytes)', () {
      final salt1 = PasswordHasher.generateSalt();
      final salt2 = PasswordHasher.generateSalt();

      expect(salt1.length, equals(32));
      expect(salt2.length, equals(32));
      expect(salt1, isNot(equals(salt2)));
    });

    test('hashPassword produces different hashes for same password with different salts', () {
      final hash1 = PasswordHasher.hashPassword('MySecretPassword123');
      final hash2 = PasswordHasher.hashPassword('MySecretPassword123');

      expect(hash1, isNot(equals(hash2)));
      expect(hash1.startsWith('pbkdf2:sha256:10000:'), isTrue);
      expect(hash2.startsWith('pbkdf2:sha256:10000:'), isTrue);
    });

    test('verifyPassword returns true for matching password and false for incorrect password', () {
      final password = 'SecuredUserPassword!@#';
      final hash = PasswordHasher.hashPassword(password);

      expect(PasswordHasher.verifyPassword(password, hash), isTrue);
      expect(PasswordHasher.verifyPassword('WrongPassword', hash), isFalse);
      expect(PasswordHasher.verifyPassword(password.toLowerCase(), hash), isFalse);
    });

    test('verifyPassword supports backward compatibility for legacy plain sha256', () {
      final password = 'LegacyPassword123';
      final legacySha256 = sha256.convert(utf8.encode(password)).toString();

      expect(PasswordHasher.verifyPassword(password, legacySha256), isTrue);
      expect(PasswordHasher.verifyPassword('WrongPassword', legacySha256), isFalse);
    });
  });
}
