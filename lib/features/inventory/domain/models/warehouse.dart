class Warehouse {
  final String id;
  final String name;
  final String? address;
  final String type; // STORE, WAREHOUSE, DEPOT
  final bool isDefault;
  final bool isActive;

  Warehouse({
    required this.id,
    required this.name,
    this.address,
    this.type = 'STORE',
    this.isDefault = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'type': type,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    return Warehouse(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      type: map['type'] as String? ?? 'STORE',
      isDefault: (map['is_default'] as int?) == 1,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  Warehouse copyWith({
    String? id,
    String? name,
    String? address,
    String? type,
    bool? isDefault,
    bool? isActive,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'STORE':
        return 'Magasin';
      case 'WAREHOUSE':
        return 'Entrepôt';
      case 'DEPOT':
        return 'Dépôt';
      default:
        return type;
    }
  }
}
