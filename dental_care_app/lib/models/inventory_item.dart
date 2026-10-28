class InventoryItem {
  final String id;
  final String name;
  final String category; // 'Medicines', 'Anesthetics', 'Dental Materials', 'Consumables'
  final String batch;
  final String expiryDate; // YYYY-MM-DD
  final double unitPrice;
  int quantity;
  final int minStockThreshold;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.batch,
    required this.expiryDate,
    required this.unitPrice,
    required this.quantity,
    this.minStockThreshold = 10,
  });

  bool get isLowStock => quantity <= minStockThreshold;

  bool get isExpiringSoon {
    try {
      final parts = expiryDate.split('-');
      if (parts.length == 3) {
        final exp = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final diff = exp.difference(DateTime.now()).inDays;
        return diff <= 90 && diff >= 0;
      }
    } catch (_) {}
    return false;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'batch': batch,
    'expiryDate': expiryDate,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'minStockThreshold': minStockThreshold,
  };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    category: json['category'] ?? 'Medicines',
    batch: json['batch'] ?? 'BATCH-001',
    expiryDate: json['expiryDate'] ?? '',
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    minStockThreshold: (json['minStockThreshold'] as num?)?.toInt() ?? 10,
  );
}
