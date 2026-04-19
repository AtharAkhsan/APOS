class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    this.address,
  });

  final String id;
  final String name;
  final String? address;

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
    );
  }
}
