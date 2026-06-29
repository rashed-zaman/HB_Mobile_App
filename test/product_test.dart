import 'package:flutter_test/flutter_test.dart';
import 'package:hb_sales/models/product.dart';

void main() {
  group('Product.fromInventoryJson', () {
    test('parses PosLookupItemDTO with availableQty and defaultRate', () {
      final product = Product.fromInventoryJson({
        'itemId': 27,
        'itemCode': 'ITEM-00027',
        'itemName': 'Agragoti',
        'defaultRate': 350.0,
        'availableQty': 2000,
      });

      expect(product.itemId, 27);
      expect(product.code, 'ITEM-00027');
      expect(product.name, 'Agragoti');
      expect(product.price, 350.0);
      expect(product.stock, 2000);
      expect(product.stockLabel, 'Stock: 2000 Pcs');
      expect(product.stockStatus, StockStatus.inStock);
    });

    test('shows out of stock when availableQty is zero', () {
      final product = Product.fromInventoryJson({
        'itemId': 27,
        'itemCode': 'ITEM-00027',
        'itemName': 'Agragoti',
        'defaultRate': 350.0,
        'availableQty': 0,
      });

      expect(product.stock, 0);
      expect(product.stockLabel, 'Stock: Out');
      expect(product.stockStatus, StockStatus.outOfStock);
    });

    test('defaults stock to zero when inventory master DTO has no qty fields', () {
      final product = Product.fromInventoryJson({
        'id': 27,
        'itemCode': 'ITEM-00027',
        'itemName': 'Agragoti',
        'price': 350.0,
      });

      expect(product.stock, 0);
      expect(product.stockLabel, 'Stock: Out');
    });
  });
}
