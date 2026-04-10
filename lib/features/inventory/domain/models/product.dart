class Product {
  final String id;
  final String name;
  final String? barcode;
  final String? reference;
  final String? category;
  final double quantity;
  final double purchasePrice;
  final double sellingPrice;
  final double alertThreshold;
  final String? description;
  final String? imagePath;
  final double weightedAverageCost;
  final String? location;
  final bool isSynced;
  final String? unit;
  final bool isService;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.reference,
    this.category,
    this.quantity = 0.0,
    this.purchasePrice = 0.0,
    this.sellingPrice = 0.0,
    this.alertThreshold = 5.0,
    this.description,
    this.imagePath,
    this.weightedAverageCost = 0.0,
    this.location,
    this.isSynced = false,
    this.unit,
    this.isService = false,
  });

  double get margin => sellingPrice - (weightedAverageCost > 0 ? weightedAverageCost : purchasePrice);
  double get marginPercent => (weightedAverageCost > 0 ? weightedAverageCost : purchasePrice) > 0 ? (margin / (weightedAverageCost > 0 ? weightedAverageCost : purchasePrice)) * 100 : 0;
  double get stockValue => isService ? 0.0 : quantity * (weightedAverageCost > 0 ? weightedAverageCost : purchasePrice);
  bool get isLowStock => !isService && quantity <= alertThreshold && quantity > 0;
  bool get isOutOfStock => !isService && quantity <= 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'reference': reference,
      'category': category,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'alertThreshold': alertThreshold,
      'description': description,
      'image_path': imagePath,
      'weighted_average_cost': weightedAverageCost,
      'location': location,
      'is_synced': isSynced ? 1 : 0,
      'unit': unit,
      'is_service': isService ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      reference: map['reference'] as String?,
      category: map['category'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      alertThreshold: (map['alertThreshold'] as num?)?.toDouble() ?? 5.0,
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
      weightedAverageCost: (map['weighted_average_cost'] as num?)?.toDouble() ?? 0.0,
      location: map['location'] as String?,
      isSynced: (map['is_synced'] as num? ?? 0) == 1,
      unit: map['unit'] as String?,
      isService: (map['is_service'] as num? ?? 0) == 1,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    String? reference,
    String? category,
    double? quantity,
    double? purchasePrice,
    double? sellingPrice,
    double? alertThreshold,
    String? description,
    String? imagePath,
    double? weightedAverageCost,
    String? location,
    bool? isSynced,
    String? unit,
    bool? isService,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      reference: reference ?? this.reference,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      weightedAverageCost: weightedAverageCost ?? this.weightedAverageCost,
      location: location ?? this.location,
      isSynced: isSynced ?? this.isSynced,
      unit: unit ?? this.unit,
      isService: isService ?? this.isService,
    );
  }
}
