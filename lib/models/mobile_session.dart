/// Parsed login / POS context from mobile auth APIs.
class EmployeeOrgMapping {
  const EmployeeOrgMapping({
    required this.organizationId,
    required this.organizationName,
    required this.businessUnitId,
    required this.businessUnitName,
    required this.locationId,
    required this.locationCode,
    required this.locationName,
    required this.storeId,
    required this.storeCode,
    required this.storeName,
    this.isActive = true,
    this.isDefault = false,
  });

  final int organizationId;
  final String organizationName;
  final int businessUnitId;
  final String businessUnitName;
  final int locationId;
  final String locationCode;
  final String locationName;
  final int storeId;
  final String storeCode;
  final String storeName;
  final bool isActive;
  final bool isDefault;

  factory EmployeeOrgMapping.fromJson(Map<String, dynamic> json) {
    return EmployeeOrgMapping(
      organizationId: json['organizationId'] as int? ?? 0,
      organizationName: json['organizationName'] as String? ?? '',
      businessUnitId: json['businessUnitId'] as int? ?? 0,
      businessUnitName: json['businessUnitName'] as String? ?? '',
      locationId: json['locationId'] as int? ?? 0,
      locationCode: json['locationCode'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      storeId: json['storeId'] as int? ?? 0,
      storeCode: json['storeCode'] as String? ?? '',
      storeName: json['storeName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class PosTerminalInfo {
  const PosTerminalInfo({
    required this.terminalId,
    required this.terminalCode,
    required this.name,
    required this.locationId,
    required this.locationCode,
    required this.locationName,
    required this.channel,
    required this.billType,
  });

  final int terminalId;
  final String terminalCode;
  final String name;
  final int locationId;
  final String locationCode;
  final String locationName;
  final String channel;
  final String billType;

  factory PosTerminalInfo.fromJson(Map<String, dynamic> json) {
    return PosTerminalInfo(
      terminalId: json['terminalId'] as int? ?? 0,
      terminalCode: json['terminalCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      locationId: json['locationId'] as int? ?? 0,
      locationCode: json['locationCode'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      billType: json['billType'] as String? ?? '',
    );
  }
}

class PosAccessInfo {
  const PosAccessInfo({
    required this.locationId,
    required this.locationCode,
    required this.locationName,
    required this.terminals,
    this.enforcement = '',
  });

  final int locationId;
  final String locationCode;
  final String locationName;
  final List<PosTerminalInfo> terminals;
  final String enforcement;

  PosTerminalInfo? get defaultTerminal =>
      terminals.isNotEmpty ? terminals.first : null;

  factory PosAccessInfo.fromJson(Map<String, dynamic> json) {
    final rawTerminals = json['terminals'];
    final terminals = rawTerminals is List
        ? rawTerminals
            .whereType<Map<String, dynamic>>()
            .map(PosTerminalInfo.fromJson)
            .toList()
        : <PosTerminalInfo>[];

    return PosAccessInfo(
      locationId: json['locationId'] as int? ?? 0,
      locationCode: json['locationCode'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      terminals: terminals,
      enforcement: json['enforcement'] as String? ?? '',
    );
  }
}
