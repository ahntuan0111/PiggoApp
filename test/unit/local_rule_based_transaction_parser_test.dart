import 'package:flutter_test/flutter_test.dart';
import 'package:appintern/core/utils/local_rule_based_transaction_parser.dart';

void main() {
  group('LocalRuleBasedTransactionParser Tests - Full Verification Suite', () {
    final categories = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Lương', 'Giải trí'];
    final userCategories = ['Mua sắm', 'Thuê nhà', 'Ăn uống', 'Đổ xăng', 'Hóa đơn'];
    final currentTime = '2026-10-26T12:00:00.000Z';

    // =========================================================================
    // NHÓM 1 — PHÂN ĐOẠN NHIỀU GIAO DỊCH (S01 - S10)
    // =========================================================================
    group('Nhóm 1 — Phân đoạn nhiều giao dịch', () {
      test('S01: "do xang 50 an bun bo 55" -> 2 giao dịch: 50.000đ — Do xang; 55.000đ — An bun bo', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50 an bun bo 55',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[0]['categoryName'], 'Đổ xăng');

        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
        expect(res[1]['categoryName'], 'Ăn uống');
      });

      test('S02: "do xang 50k an bun bo 55k" -> 2 giao dịch: 50.000đ và 55.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50k an bun bo 55k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });

      test('S03: "50 do xang 55 an bun bo" -> 2 giao dịch; số tiền đứng trước mô tả', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: '50 do xang 55 an bun bo',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });

      test('S04: "an bun bo 55 do xang 50" -> 2 giao dịch; ghi chú và số tiền không bị đảo', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'an bun bo 55 do xang 50',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 55000.0);
        expect(res[0]['note'], 'An bun bo');
        expect(res[0]['categoryName'], 'Ăn uống');

        expect(res[1]['amount'], 50000.0);
        expect(res[1]['note'], 'Do xang');
        expect(res[1]['categoryName'], 'Đổ xăng');
      });

      test('S05: "do xang 50 va an bun bo 55" -> 2 giao dịch, nhận diện từ nối không dấu va', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50 va an bun bo 55',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });

      test('S06: "do xang 50 voi an bun bo 55" -> 2 giao dịch, nhận diện từ nối không dấu voi', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50 voi an bun bo 55',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });

      test('S07: "do xang 50, an bun bo 55" -> 2 giao dịch, dấu phẩy là dấu phân cách', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50, an bun bo 55',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });

      test('S08: "do xang 50 + an bun bo 55" -> 2 giao dịch, dấu + là dấu phân cách', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50 + an bun bo 55',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });

      test('S09: "do xang 50; an bun bo 55" -> 2 giao dịch, dấu chấm phẩy là dấu phân cách', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50; an bun bo 55',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });

      test('S10: "hom nay do xang 50 an bun bo 55" -> 2 giao dịch; tiền tố thời gian không dính sai cách', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'hom nay do xang 50 an bun bo 55',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
      });
    });

    // =========================================================================
    // NHÓM 2 — SỐ TIỀN, ĐƠN VỊ LÓNG VÀ DẤU PHÂN CÁCH (M01 - M14)
    // =========================================================================
    group('Nhóm 2 — Số tiền, đơn vị lóng và dấu phân cách', () {
      test('M01: "an pho 45k" -> 1 giao dịch — 45.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'an pho 45k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 45000.0);
        expect(res[0]['categoryName'], 'Ăn uống');
      });

      test('M02: "mua ao 200 canh" -> 1 giao dịch — 200.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua ao 200 canh',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 200000.0);
        expect(res[0]['categoryName'], 'Mua sắm');
      });

      test('M03: "thue nha 3 trieu tien dien 500k" -> 2 giao dịch — 3.000.000đ và 500.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'thue nha 3 trieu tien dien 500k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 3000000.0);
        expect(res[0]['categoryName'], 'Thuê nhà');
        expect(res[1]['amount'], 500000.0);
        expect(res[1]['categoryName'], 'Hóa đơn');
      });

      test('M04: "mua dien thoai 2 cu" -> 1 giao dịch — 2.000.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua dien thoai 2 cu',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 2000000.0);
      });

      test('M05: "mua do 500 nghin" -> 1 giao dịch — 500.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua do 500 nghin',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 500000.0);
      });

      test('M06: "do xang 1,5 trieu" -> 1 giao dịch — 1.500.000đ; không bị tách dấu phẩy thập phân', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 1,5 trieu',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 1500000.0);
        expect(res[0]['note'], 'Do xang');
      });

      test('M07: "do xang 1.5 trieu" -> 1 giao dịch — 1.500.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 1.5 trieu',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 1500000.0);
        expect(res[0]['note'], 'Do xang');
      });

      test('M08: "mua do 20.000đ" -> 1 giao dịch — 20.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua do 20.000đ',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 200000.0 != 20000.0 ? 20000.0 : 20000.0);
        expect(res[0]['amount'], 20000.0);
      });

      test('M09: "mua do 1.500.000đ" -> 1 giao dịch — 1.500.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua do 1.500.000đ',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 1500000.0);
      });

      test('M10: "mua do 12,5k" -> 1 giao dịch — 12.500đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua do 12,5k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 12500.0);
      });

      test('M11: "mua do 12.5k" -> 1 giao dịch — 12.500đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua do 12.5k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 12500.0);
      });

      test('M12: "do xang 50" -> 1 giao dịch — 50.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 50000.0);
      });

      test('M13: "do xang 500" -> 1 giao dịch — 500.000đ (quy tắc số trần < 1000)', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 500',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 500000.0);
      });

      test('M14: "do xang -50k" -> không âm thầm hiểu thành dương 50.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang -50k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        // Số tiền không được là 50000.0 dương
        expect(res.isEmpty || res[0]['amount'] != 50000.0, isTrue);
      });
    });

    // =========================================================================
    // NHÓM 3 — GHI CHÚ ĐẶC BIỆT VÀ RANH GIỚI TỪ (N01 - N12)
    // =========================================================================
    group('Nhóm 3 — Ghi chú đặc biệt và ranh giới từ', () {
      test('N01: "50" -> Ghi chú rỗng', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: '50',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], '');
      });

      test('N02: "hom nay 50" -> Ghi chú rỗng sau khi loại số tiền và tiền tố thời gian', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'hom nay 50',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], '');
      });

      test('N03: "mua vali 50" -> Ghi chú "Mua vali"; không tách theo "va"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua vali 50',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Mua vali');
      });

      test('N04: "toi mua do an 50k" -> Giữ ý nghĩa "Toi mua do an"; không tự xóa "toi"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'toi mua do an 50k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Toi mua do an');
      });

      test('N05: "toi uu 50k" -> Ghi chú "Toi uu"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'toi uu 50k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Toi uu');
        expect(res[0]['categoryName'], isNull);
      });

      test('N06: "tra sua 35k" -> Ghi chú "Tra sua"; không xóa nhầm "tra"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'tra sua 35k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 35000.0);
        expect(res[0]['note'], 'Tra sua');
      });

      test('N07: "chi phi dien 100k" -> Ghi chú "Chi phi dien"; không xóa nhầm "chi"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'chi phi dien 100k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 100000.0);
        expect(res[0]['note'], 'Chi phi dien');
      });

      test('N08: "mat kinh 250k" -> Ghi chú "Mat kinh"; không xóa nhầm "mat"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mat kinh 250k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 250000.0);
        expect(res[0]['note'], 'Mat kinh');
      });

      test('N09: "chill 20k" -> Ghi chú "Chill"; không xóa phần "chi" trong "chill"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'chill 20k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 20000.0);
        expect(res[0]['note'], 'Chill');
      });

      test('N10: "mua ao 200k" -> Ghi chú "Mua ao"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua ao 200k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 200000.0);
        expect(res[0]['note'], 'Mua ao');
      });

      test('N11: "mua ao 200k va mua quan 300k" -> Hai ghi chú độc lập: "Mua ao", "Mua quan"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua ao 200k va mua quan 300k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 200000.0);
        expect(res[0]['note'], 'Mua ao');

        expect(res[1]['amount'], 300000.0);
        expect(res[1]['note'], 'Mua quan');
      });

      test('N12: "mua ao 200k" có nhiều khoảng trắng thừa -> Ghi chú chuẩn hóa', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: '   mua    ao    200k   ',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 200000.0);
        expect(res[0]['note'], 'Mua ao');
      });
    });

    // =========================================================================
    // NHÓM 4 — TRƯỜNG HỢP MƠ HỒ VÀ DỄ TẠO GIAO DỊCH GIẢ (E01 - E10)
    // =========================================================================
    group('Nhóm 4 — Trường hợp mơ hồ và dễ tạo giao dịch giả', () {
      test('E01: "mua 2 ao 200k" -> 1 giao dịch — 200.000đ; ghi chú "Mua 2 ao"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua 2 ao 200k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 200000.0);
        expect(res[0]['note'], 'Mua 2 ao');
        expect(res[0]['categoryName'], 'Mua sắm');
      });

      test('E02: "mua 3 ly cafe 90k" -> 1 giao dịch — 90.000đ; số lượng 3 không tạo giao dịch riêng', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua 3 ly cafe 90k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 90000.0);
        expect(res[0]['note'], 'Mua 3 ly cafe');
        expect(res[0]['categoryName'], 'Ăn uống');
      });

      test('E03: "mua 2 ao 200k an bun bo 55k" -> 2 giao dịch; không tạo giao dịch giả 2.000đ', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua 2 ao 200k an bun bo 55k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 200000.0);
        expect(res[0]['note'], 'Mua 2 ao');
        expect(res[0]['categoryName'], 'Mua sắm');

        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
        expect(res[1]['categoryName'], 'Ăn uống');
      });

      test('E04: "ca phe 25k va banh mi 15k" -> 2 giao dịch, mỗi giao dịch có một mốc tiền', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'ca phe 25k va banh mi 15k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 25000.0);
        expect(res[0]['note'], 'Ca phe');

        expect(res[1]['amount'], 15000.0);
        expect(res[1]['note'], 'Banh mi');
      });

      test('E05: "banh mi 15k 5k" -> Không âm thầm bỏ số tiền thứ hai', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'banh mi 15k 5k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 15000.0);
        expect(res[0]['note'], 'Banh mi');
        expect(res[1]['amount'], 5000.0);
      });

      test('E06: "mua do 100k, 50k" -> Tách 2 giao dịch', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua do 100k, 50k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 100000.0);
        expect(res[0]['note'], 'Mua do');
        expect(res[1]['amount'], 50000.0);
      });

      test('E07: "an bun bo" -> Không tự tạo giao dịch hoàn chỉnh khi thiếu số tiền (amount = 0.0)', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'an bun bo',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 0.0);
        expect(res[0]['categoryName'], 'Ăn uống');
        expect(res[0]['note'], 'an bun bo');
      });

      test('E08: "nhan luong 15 trieu mua ao 200k" -> Tách 2 giao dịch và phân loại thu nhập/chi tiêu riêng biệt', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'nhan luong 15 trieu mua ao 200k',
          availableCategories: categories,
          currentTime: currentTime,
        );

        expect(res.length, 2);
        expect(res[0]['amount'], 15000000.0);
        expect(res[0]['type'], 'inflow');
        expect(res[0]['categoryName'], 'Lương');
        expect(res[0]['note'], 'Nhan luong');

        expect(res[1]['amount'], 200000.0);
        expect(res[1]['type'], 'outflow');
        expect(res[1]['categoryName'], 'Mua sắm');
        expect(res[1]['note'], 'Mua ao');
      });

      test('E09: "do xang 50 an bun bo 55 va mua ao 100" -> 3 giao dịch', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'do xang 50 an bun bo 55 va mua ao 100',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 3);
        expect(res[0]['amount'], 50000.0);
        expect(res[0]['note'], 'Do xang');
        expect(res[0]['categoryName'], 'Đổ xăng');

        expect(res[1]['amount'], 55000.0);
        expect(res[1]['note'], 'An bun bo');
        expect(res[1]['categoryName'], 'Ăn uống');

        expect(res[2]['amount'], 100000.0);
        expect(res[2]['note'], 'Mua ao');
        expect(res[2]['categoryName'], 'Mua sắm');
      });

      test('E10: "mua quan ao 200k" -> 1 giao dịch; không nhầm "quần áo" thành "Ăn uống"', () {
        final res = LocalRuleBasedTransactionParser.parse(
          text: 'mua quan ao 200k',
          availableCategories: userCategories,
          currentTime: currentTime,
        );

        expect(res.length, 1);
        expect(res[0]['amount'], 200000.0);
        expect(res[0]['categoryName'], 'Mua sắm');
        expect(res[0]['note'], 'Mua quan ao');
      });
    });
  });
}
