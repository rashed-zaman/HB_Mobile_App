class PosBillSummary {
  const PosBillSummary({
    this.totalItems,
    this.totalAmount = 0,
    this.discountAmount = 0,
    this.netPayable = 0,
    this.totalPaid = 0,
    this.netCreditAmount = 0,
  });

  final int? totalItems;
  final double totalAmount;
  final double discountAmount;
  final double netPayable;
  final double totalPaid;
  final double netCreditAmount;

  double get changeGiven =>
      netCreditAmount < 0 ? netCreditAmount.abs() : 0;

  factory PosBillSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PosBillSummary();
    return PosBillSummary(
      totalItems: json['totalItems'] as int?,
      totalAmount: _toDouble(json['totalAmount']),
      discountAmount: _toDouble(json['discountAmount']),
      netPayable: _toDouble(json['netPayable']),
      totalPaid: _toDouble(json['totalPaid']),
      netCreditAmount: _toDouble(json['netCreditAmount']),
    );
  }
}

class PosBillLineItem {
  const PosBillLineItem({
    this.itemId,
    this.itemCode = '',
    this.itemName = '',
    this.quantity = 0,
    this.rate = 0,
    this.subtotal = 0,
  });

  final int? itemId;
  final String itemCode;
  final String itemName;
  final double quantity;
  final double rate;
  final double subtotal;

  factory PosBillLineItem.fromJson(Map<String, dynamic> json) {
    return PosBillLineItem(
      itemId: json['itemId'] as int?,
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      quantity: _toDouble(json['quantity']),
      rate: _toDouble(json['rate']),
      subtotal: _toDouble(json['subtotal']),
    );
  }
}

class PosBillPaymentLine {
  const PosBillPaymentLine({
    this.configId,
    this.paymentMethod = '',
    this.providerName,
    this.accountReference,
    this.amount = 0,
  });

  final int? configId;
  final String paymentMethod;
  final String? providerName;
  final String? accountReference;
  final double amount;

  factory PosBillPaymentLine.fromJson(Map<String, dynamic> json) {
    return PosBillPaymentLine(
      configId: json['configId'] as int? ?? json['id'] as int?,
      paymentMethod: json['paymentMethod']?.toString().toUpperCase() ?? '',
      providerName: json['providerName']?.toString(),
      accountReference: json['accountReference']?.toString(),
      amount: _toDouble(json['amount']),
    );
  }
}

class PosBillResponse {
  const PosBillResponse({
    this.id,
    this.billNumber = '',
    this.storeName = '',
    this.storeCode = '',
    this.customerName = '',
    this.customerCode = '',
    this.phoneNo = '',
    this.billType = 'EXPRESS',
    this.saleDate,
    this.memoNo = '',
    this.summary = const PosBillSummary(),
    this.items = const [],
    this.payments = const [],
  });

  final int? id;
  final String billNumber;
  final String storeName;
  final String storeCode;
  final String customerName;
  final String customerCode;
  final String phoneNo;
  final String billType;
  final DateTime? saleDate;
  final String memoNo;
  final PosBillSummary summary;
  final List<PosBillLineItem> items;
  final List<PosBillPaymentLine> payments;

  factory PosBillResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final paymentsRaw = json['payments'];
    return PosBillResponse(
      id: json['id'] as int?,
      billNumber: json['billNumber']?.toString() ?? '',
      storeName: json['storeName']?.toString() ?? '',
      storeCode: json['storeCode']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerCode: json['customerCode']?.toString() ?? '',
      phoneNo: json['phoneNo']?.toString() ?? '',
      billType: json['billType']?.toString() ?? 'EXPRESS',
      saleDate: _parseDate(json['saleDate']),
      memoNo: json['memoNo']?.toString() ?? '',
      summary: PosBillSummary.fromJson(
        json['summary'] as Map<String, dynamic>?,
      ),
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map<String, dynamic>>()
              .map(PosBillLineItem.fromJson)
              .toList()
          : const [],
      payments: paymentsRaw is List
          ? paymentsRaw
              .whereType<Map<String, dynamic>>()
              .map(PosBillPaymentLine.fromJson)
              .toList()
          : const [],
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  return DateTime.tryParse(s);
}
