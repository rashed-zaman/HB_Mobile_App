class Customer {
  const Customer({
    this.id,
    required this.name,
    required this.code,
    required this.phone,
  });

  final int? id;
  final String name;
  final String code;
  final String phone;

  factory Customer.fromStakeholderJson(Map<String, dynamic> json) {
    return Customer(
      id: _nullableInt(json['id']),
      name: _firstNonEmpty([
        json['businessName'],
        json['customerName'],
        json['name'],
      ]),
      code: _firstNonEmpty([
        json['code'],
        json['customerCode'],
      ]),
      phone: _firstNonEmpty([
        json['contactNo1'],
        json['phoneNo'],
        json['phone'],
      ]),
    );
  }
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}
