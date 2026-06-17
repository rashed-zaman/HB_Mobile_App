/// Settlement slip data returned by the backend.
/// Maps to `PosSalesSettlementListItemDTO` + `PosSettlementPaymentBreakdownDTO`.
class PosSettlementPaymentLine {
  const PosSettlementPaymentLine({
    required this.lineKind,
    this.paymentMethod,
    this.providerName,
    required this.displayLabel,
    required this.amount,
  });

  /// 'PAYMENT' or 'CREDIT'
  final String lineKind;
  final String? paymentMethod;
  final String? providerName;
  final String displayLabel;
  final double amount;

  bool get isCredit => lineKind.toUpperCase() == 'CREDIT';

  factory PosSettlementPaymentLine.fromJson(Map<String, dynamic> json) {
    return PosSettlementPaymentLine(
      lineKind: json['lineKind']?.toString() ?? 'PAYMENT',
      paymentMethod: json['paymentMethod']?.toString(),
      providerName: json['providerName']?.toString(),
      displayLabel: json['displayLabel']?.toString() ?? '',
      amount: _toDouble(json['amount']),
    );
  }
}

class PosSettlementPaymentBreakdown {
  const PosSettlementPaymentBreakdown({
    required this.lines,
    required this.totalCollected,
    required this.totalCredit,
    required this.grandTotal,
  });

  final List<PosSettlementPaymentLine> lines;
  final double totalCollected;
  final double totalCredit;
  final double grandTotal;

  factory PosSettlementPaymentBreakdown.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PosSettlementPaymentBreakdown(
        lines: [],
        totalCollected: 0,
        totalCredit: 0,
        grandTotal: 0,
      );
    }
    final rawLines = json['lines'];
    return PosSettlementPaymentBreakdown(
      lines: rawLines is List
          ? rawLines
              .whereType<Map<String, dynamic>>()
              .map(PosSettlementPaymentLine.fromJson)
              .toList()
          : const [],
      totalCollected: _toDouble(json['totalCollected']),
      totalCredit: _toDouble(json['totalCredit']),
      grandTotal: _toDouble(json['grandTotal']),
    );
  }
}

class PosSettlementDto {
  const PosSettlementDto({
    required this.settlementId,
    this.signinId,
    this.employeeId,
    this.employeeName,
    this.employeeCode,
    this.terminalId,
    this.terminalCode,
    this.terminalName,
    this.locationId,
    this.locationName,
    this.totalInvoice,
    this.totalInvoiceAmount,
    this.totalCreditAmount,
    this.acceptedChangeMoneyAmount,
    required this.paymentBreakdown,
    this.createdDate,
    this.signinDatetime,
    this.settlementAccepted,
    this.settlementDatetime,
  });

  final int settlementId;
  final int? signinId;
  final int? employeeId;
  final String? employeeName;
  final String? employeeCode;
  final int? terminalId;
  final String? terminalCode;
  final String? terminalName;
  final int? locationId;
  final String? locationName;
  final int? totalInvoice;
  final double? totalInvoiceAmount;
  final double? totalCreditAmount;
  final double? acceptedChangeMoneyAmount;
  final PosSettlementPaymentBreakdown paymentBreakdown;
  final DateTime? createdDate;
  final DateTime? signinDatetime;
  final bool? settlementAccepted;
  final DateTime? settlementDatetime;

  factory PosSettlementDto.fromJson(Map<String, dynamic> json) {
    return PosSettlementDto(
      settlementId: (json['settlementId'] as num).toInt(),
      signinId: (json['signinId'] as num?)?.toInt(),
      employeeId: (json['employeeId'] as num?)?.toInt(),
      employeeName: json['employeeName']?.toString(),
      employeeCode: json['employeeCode']?.toString(),
      terminalId: (json['terminalId'] as num?)?.toInt(),
      terminalCode: json['terminalCode']?.toString(),
      terminalName: json['terminalName']?.toString(),
      locationId: (json['locationId'] as num?)?.toInt(),
      locationName: json['locationName']?.toString(),
      totalInvoice: (json['totalInvoice'] as num?)?.toInt(),
      totalInvoiceAmount: _toDouble(json['totalInvoiceAmount']),
      totalCreditAmount: _toDouble(json['totalCreditAmount']),
      acceptedChangeMoneyAmount: _toDoubleNullable(json['acceptedChangeMoneyAmount']),
      paymentBreakdown: PosSettlementPaymentBreakdown.fromJson(
        json['paymentBreakdown'] as Map<String, dynamic>?,
      ),
      createdDate: _parseDate(json['createdDate']),
      signinDatetime: _parseDate(json['signinDatetime']),
      settlementAccepted: json['settlementAccepted'] as bool?,
      settlementDatetime: _parseDate(json['settlementDatetime']),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

double? _toDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
