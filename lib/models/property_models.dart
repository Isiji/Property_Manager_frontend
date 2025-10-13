// lib/models/property_models.dart
class PropertyLite {
  final int id;
  final String name;
  final String address;
  final String propertyCode;

  PropertyLite({
    required this.id,
    required this.name,
    required this.address,
    required this.propertyCode,
  });

  factory PropertyLite.fromJson(Map<String, dynamic> j) => PropertyLite(
        id: j['id'],
        name: j['name'],
        address: j['address'],
        propertyCode: j['property_code'] ?? '',
      );
}

class UnitLite {
  final int id;
  final String number;
  final String rentAmount;
  final String status; // "occupied" or "vacant"
  final Map<String, dynamic>? tenant;

  UnitLite({
    required this.id,
    required this.number,
    required this.rentAmount,
    required this.status,
    required this.tenant,
  });

  factory UnitLite.fromJson(Map<String, dynamic> j) => UnitLite(
        id: j['id'],
        number: j['number'],
        rentAmount: j['rent_amount'].toString(),
        status: j['status']?.toString() ?? (j['occupied'] == 1 ? "occupied" : "vacant"),
        tenant: j['tenant'],
      );
}

class PropertyWithUnits {
  final int id;
  final String name;
  final String address;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final List<UnitLite> units;

  PropertyWithUnits({
    required this.id,
    required this.name,
    required this.address,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.units,
  });

  factory PropertyWithUnits.fromJson(Map<String, dynamic> j) => PropertyWithUnits(
        id: j['id'],
        name: j['name'],
        address: j['address'] ?? '',
        totalUnits: j['total_units'] ?? 0,
        occupiedUnits: j['occupied_units'] ?? 0,
        vacantUnits: j['vacant_units'] ?? 0,
        units: (j['units'] as List<dynamic>).map((e) => UnitLite.fromJson(e)).toList(),
      );
}
