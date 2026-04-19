/// Product entity for the domain layer.
class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    this.categoryId,
    this.imageUrl,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.currentStock,
    this.unit = 'pcs',
    this.isActive = true,
  });

  final String id;
  final String sku;
  final String name;
  final String? categoryId;
  final String? imageUrl;
  final double purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final String unit;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      imageUrl: json['image_url'] as String?,
      purchasePrice: (json['purchase_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      currentStock: (json['current_stock'] as num).toInt(),
      unit: json['unit'] as String? ?? 'pcs',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Converts to a JSON map suitable for Supabase INSERT.
  /// Omits `id` so the database generates a UUID.
  Map<String, dynamic> toInsertJson() => {
        'sku': sku,
        'name': name,
        if (categoryId != null) 'category_id': categoryId,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'unit': unit,
        'is_active': isActive,
      };

  Product copyWith({
    String? id,
    String? sku,
    String? name,
    String? categoryId,
    String? imageUrl,
    double? purchasePrice,
    double? sellingPrice,
    int? currentStock,
    String? unit,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
    );
  }
}
