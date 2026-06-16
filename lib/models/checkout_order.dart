/// One cart line for express bill submit.
class CheckoutLineItem {
  const CheckoutLineItem({
    this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.rate,
    this.thanQty = 0,
  });

  final int? itemId;
  final String itemCode;
  final String itemName;
  final double quantity;
  final double rate;
  final double thanQty;

  Map<String, dynamic> toBillJson() => {
        if (itemId != null && itemId! > 0) 'itemId': itemId,
        'itemCode': itemCode,
        'itemName': itemName,
        'thanQty': thanQty,
        'quantity': quantity,
        'rate': rate,
      };
}

/// Customer context for express bill submit.
class CheckoutCustomerInfo {
  const CheckoutCustomerInfo({
    this.customerId,
    this.customerCode,
    this.customerName,
    this.phoneNo,
  });

  final int? customerId;
  final String? customerCode;
  final String? customerName;
  final String? phoneNo;

  Map<String, dynamic> toBillJson() => {
        if (customerId != null && customerId! > 0) 'customerId': customerId,
        if (customerCode != null && customerCode!.trim().isNotEmpty)
          'customerCode': customerCode!.trim(),
        if (customerName != null && customerName!.trim().isNotEmpty)
          'customerName': customerName!.trim(),
        if (phoneNo != null && phoneNo!.trim().isNotEmpty)
          'phoneNo': phoneNo!.trim(),
      };
}
