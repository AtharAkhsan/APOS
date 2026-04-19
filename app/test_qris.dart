import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void main() async {
  const supabaseUrl = 'https://bifiyppbqubakllgouci.supabase.co';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZml5cHBicXViYWtsbGdvdWNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjYyMDAsImV4cCI6MjA5MDA0MjIwMH0.SrN0euyuPjeBCqJDxdz2GYFFBE6okusSW4IbOcjplDA';

  // 1. Fetch a real product from DB
  final pdReq = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/products?select=id,name,selling_price&limit=1'),
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
    }
  );

  final products = jsonDecode(pdReq.body);
  if (products.isEmpty) {
    print('No products found in DB to test with.');
    return;
  }
  
  final product = products[0];
  print('Testing with real product: ' + product["name"] + ' (' + product["id"] + ')');

  // 2. Call create-qris with real data
  final url = Uri.parse('$supabaseUrl/functions/v1/create-qris');
  final request = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $anonKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'order_id': const Uuid().v4(),
      'gross_amount': product['selling_price'],
      'cart_items': [
        {
          'product_id': product['id'],
          'name': product['name'],
          'quantity': 1,
          'price': product['selling_price'],
        }
      ]
    })
  );

  print('Status Code: ${request.statusCode}');
  print('Response Body: ${request.body}');
}
