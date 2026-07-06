import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/core/network/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/domain/repositories/category_repository.dart';

class HomeController extends BaseController {
  final storage = Get.find<StorageService>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();

  var userName = "Đang tải...".obs;
  var currentUserId = "".obs;

  // Thay thế tĩnh bằng Biến số Rx để UI tự cập nhật khi dữ liệu đổi
  final currentMonth = 'Tháng 7 2026'.obs;

  final salary = 0.0.obs;
  final allocatedAmount = 0.0.obs;

  final categories = <BudgetCategory>[].obs;

  @override
  void onInit() {
    super.onInit();
    userName.value = storage.read(AppKeys.userName) ?? "Đang tải...";
    currentUserId.value = storage.read(AppKeys.userId) ?? "";
  }

  @override
  void onReady() {
    super.onReady();
    fetchData();
  }

  Future<void> fetchData() async {
    final userId = currentUserId.value;
    if (userId.isEmpty) return;

    try {
      final types = await categoryRepository.getCategoryTypes(userId);
      if (types.isNotEmpty) {
        final typeIds = types.map((e) => e.id).toList();
        final cats = await categoryRepository.getCategories(typeIds);
        
        categories.value = cats.map((c) => BudgetCategory(
          icon: c.iconName,
          name: c.name,
          allocated: c.defaultBudget,
          spent: 0.0,
        )).toList();
      } else {
        categories.clear();
      }
    } catch (e) {
      print("Error fetching home categories: $e");
    }
  }

  // Hàm tiện ích format tiền tệ (thay cho thư viện intl để giữ app nhẹ)
  String formatCurrency(double amount) {
    String numStr = amount.toStringAsFixed(0);
    return numStr.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        ) +
        'đ';
  }
}
