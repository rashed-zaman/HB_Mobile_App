/// Shift sign-in data from `POST /api/mobile/pos/signin` (`data` payload).
class PosSignInDto {
  const PosSignInDto({
    this.signinId,
    this.employeeId,
    this.employeeName,
    this.terminalId,
    this.terminalCode,
    this.terminalName,
    this.signinDatetime,
    this.signoutDatetime,
    this.organizationId,
    this.organizationName,
    this.businessUnitId,
    this.businessUnitName,
    this.locationId,
    this.locationCode,
    this.locationName,
    this.storeId,
    this.storeCode,
    this.storeName,
    this.signinFlag,
    this.currentUserSignedIn,
    this.orderCount,
    this.totalAmount,
    this.postedOrderCount,
    this.postedTotalAmount,
  });

  final int? signinId;
  final int? employeeId;
  final String? employeeName;
  final int? terminalId;
  final String? terminalCode;
  final String? terminalName;
  final DateTime? signinDatetime;
  final DateTime? signoutDatetime;
  final int? organizationId;
  final String? organizationName;
  final int? businessUnitId;
  final String? businessUnitName;
  final int? locationId;
  final String? locationCode;
  final String? locationName;
  final int? storeId;
  final String? storeCode;
  final String? storeName;
  final bool? signinFlag;
  final bool? currentUserSignedIn;
  final int? orderCount;
  final double? totalAmount;
  final int? postedOrderCount;
  final double? postedTotalAmount;

  factory PosSignInDto.fromJson(Map<String, dynamic> json) {
    return PosSignInDto(
      signinId: (json['signinId'] as num?)?.toInt(),
      employeeId: (json['employeeId'] as num?)?.toInt(),
      employeeName: json['employeeName']?.toString(),
      terminalId: (json['terminalId'] as num?)?.toInt(),
      terminalCode: json['terminalCode']?.toString(),
      terminalName: json['terminalName']?.toString(),
      signinDatetime: _parseDate(json['signinDatetime']),
      signoutDatetime: _parseDate(json['signoutDatetime']),
      organizationId: (json['organizationId'] as num?)?.toInt(),
      organizationName: json['organizationName']?.toString(),
      businessUnitId: (json['businessUnitId'] as num?)?.toInt(),
      businessUnitName: json['businessUnitName']?.toString(),
      locationId: (json['locationId'] as num?)?.toInt(),
      locationCode: json['locationCode']?.toString(),
      locationName: json['locationName']?.toString(),
      storeId: (json['storeId'] as num?)?.toInt(),
      storeCode: json['storeCode']?.toString(),
      storeName: json['storeName']?.toString(),
      signinFlag: json['signinFlag'] as bool?,
      currentUserSignedIn: json['currentUserSignedIn'] as bool?,
      orderCount: (json['orderCount'] as num?)?.toInt(),
      totalAmount: _toDoubleNullable(json['totalAmount']),
      postedOrderCount: (json['postedOrderCount'] as num?)?.toInt(),
      postedTotalAmount: _toDoubleNullable(json['postedTotalAmount']),
    );
  }
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
