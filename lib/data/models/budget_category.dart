class BudgetCategory {
  final String icon;
  final String name;
  final double allocated;
  final double spent;

  BudgetCategory({
    required this.icon,
    required this.name,
    required this.allocated,
    required this.spent,
  });

  double get remaining => allocated - spent;
  double get progress => allocated == 0 ? 0 : spent / allocated;
}
