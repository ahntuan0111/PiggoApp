import 'package:appintern/data/models/budget_category.dart';

class BudgetCategoryGroup {
  final String typeId;
  final String typeName;
  final List<BudgetCategory> categories;

  BudgetCategoryGroup(this.typeId, this.typeName, this.categories);
}
