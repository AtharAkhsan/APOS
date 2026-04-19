import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';

/// Simple category model
class Category {
  final String id;
  final String name;
  final String? description;

  const Category({required this.id, required this.name, this.description});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
      );
}

/// Fetches all categories from Supabase
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client
      .from('categories')
      .select('id, name, description')
      .order('name');
  return (data as List)
      .map((e) => Category.fromJson(e as Map<String, dynamic>))
      .toList();
});
