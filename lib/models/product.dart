enum StockStatus { inStock, lowStock, outOfStock }

class Product {
  final String name;
  final String code;
  final int stock;
  final double price;

  const Product({
    required this.name,
    required this.code,
    required this.stock,
    required this.price,
  });

  StockStatus get stockStatus {
    if (stock == 0) return StockStatus.outOfStock;
    if (stock <= 5) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  String get stockLabel {
    if (stock == 0) return 'Stock: Out';
    return 'Stock: $stock Pcs';
  }

  /// Parses one inventory item object from the mobile API (field names may vary).
  factory Product.fromInventoryJson(Map<String, dynamic> json) {
    return Product(
      name: _stringFrom(json, const [
            'itemName',
            'name',
            'productName',
            'description',
            'title',
          ]) ??
          'Unknown',
      code: _stringFrom(json, const [
            'code',
            'itemCode',
            'sku',
            'barcode',
            'productCode',
          ]) ??
          '',
      stock: _intFrom(json, const [
        'stock',
        'quantity',
        'availableQuantity',
        'currentStock',
        'qty',
        'onHand',
      ]),
      price: _doubleFrom(json, const [
        'price',
        'salePrice',
        'unitPrice',
        'mrp',
        'rate',
        'sellingPrice',
      ]),
    );
  }
}

String? _stringFrom(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

int _intFrom(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    if (v is int) return v;
    if (v is double) return v.round();
    final p = int.tryParse(v.toString());
    if (p != null) return p;
  }
  return 0;
}

double _doubleFrom(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    if (v is num) return v.toDouble();
    final p = double.tryParse(v.toString());
    if (p != null) return p;
  }
  return 0;
}
