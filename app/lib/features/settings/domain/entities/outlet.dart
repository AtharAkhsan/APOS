/// Outlet entity for the domain layer.
class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        'is_active': isActive,
      };

  Outlet copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    bool? isActive,
  }) {
    return Outlet(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
    );
  }
}
