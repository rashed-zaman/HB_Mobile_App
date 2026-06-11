class BoundDeviceData {
  const BoundDeviceData({
    required this.bound,
    required this.deviceUuid,
    required this.displayName,
    required this.terminalCode,
    required this.active,
    this.message,
  });

  final bool bound;
  final String deviceUuid;
  final String displayName;
  final String terminalCode;
  final bool active;
  final String? message;

  factory BoundDeviceData.fromJson(Map<String, dynamic> json) {
    return BoundDeviceData(
      bound: json['bound'] as bool? ?? false,
      deviceUuid: json['deviceUuid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      terminalCode: json['terminalCode'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'bound': bound,
        'deviceUuid': deviceUuid,
        'displayName': displayName,
        'terminalCode': terminalCode,
        'active': active,
        'message': message,
      };

  bool get isSaved => bound && deviceUuid.trim().isNotEmpty;
}
