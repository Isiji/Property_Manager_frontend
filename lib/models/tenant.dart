class Tenant {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? idNumber;           // National ID (optional)
  final int propertyId;
  final int unitId;
  final String? propertyName;       // optional if backend returns it
  final String? unitLabel;          // e.g. “A-12” / house number
  final String rentStatus;          // "paid" | "partial" | "overdue"
  final double? currentBalance;     // positive = owes, negative = credit

  Tenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.propertyId,
    required this.unitId,
    required this.rentStatus,
    this.email,
    this.idNumber,
    this.propertyName,
    this.unitLabel,
    this.currentBalance,
  });

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
        id: j['id'] as int,
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'],
        idNumber: j['id_number'],
        propertyId: j['property_id'] as int,
        unitId: j['unit_id'] as int,
        propertyName: j['property_name'],
        unitLabel: j['unit_label'] ?? j['house_number'], // support either
        rentStatus: (j['rent_status'] ?? 'unknown').toString().toLowerCase(),
        currentBalance: j['current_balance'] == null
            ? null
            : double.tryParse(j['current_balance'].toString()),
      );
}
