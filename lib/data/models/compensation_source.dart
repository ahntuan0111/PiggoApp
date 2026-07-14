class CompensationSource {
  String sourceId; // ID của category hoặc 'unallocated'
  String sourceName;
  String iconName;
  double availableAmount;
  double amountToCompensate;

  CompensationSource({
    required this.sourceId,
    required this.sourceName,
    required this.iconName,
    required this.availableAmount,
    this.amountToCompensate = 0.0,
  });
}
