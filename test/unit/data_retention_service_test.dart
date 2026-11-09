import 'package:flutter_test/flutter_test.dart';
import 'package:appintern/core/services/data_retention_service.dart';

void main() {
  group('DataRetentionService Logic Tests', () {
    test('calculateCutoffDate calculates correct 2 months retention boundary', () {
      final service = DataRetentionService(
        localDb: null,
        storage: null,
      );

      final cutoff = service.calculateCutoffDate(2);
      final now = DateTime.now();

      // Cho retentionMonths = 2:
      // Tháng hiện tại = T (now.month)
      // Tháng trước = T - 1 (now.month - 1)
      // Cutoff Date là ngày 1 của tháng T - 1 lúc 00:00:00
      final expectedMonth = now.month - 1;
      final expectedDate = DateTime(now.year, expectedMonth, 1);

      expect(cutoff.year, equals(expectedDate.year));
      expect(cutoff.month, equals(expectedDate.month));
      expect(cutoff.day, equals(1));
      expect(cutoff.isBefore(now), isTrue);
    });

    test('RetentionStats calculates human-readable size correctly', () {
      final stats0 = RetentionStats(freedBytes: 0);
      expect(stats0.freedSizeFormatted, equals('0 B'));

      final statsBytes = RetentionStats(freedBytes: 500);
      expect(statsBytes.freedSizeFormatted, equals('500 B'));

      final statsKb = RetentionStats(freedBytes: 1536);
      expect(statsKb.freedSizeFormatted, equals('1.5 KB'));

      final statsMb = RetentionStats(freedBytes: 5242880);
      expect(statsMb.freedSizeFormatted, equals('5.00 MB'));
    });
  });
}

