import 'package:supabase_flutter/supabase_flutter.dart';

class QrisPaymentRepository {
  QrisPaymentRepository(this._supabase);
  final SupabaseClient _supabase;

  /// Invokes the `create-qris` Edge Function to generate a Midtrans QRIS.
  /// Returns the QR String URL on success.
  Future<String> createQrisTransaction({
    required String orderId,
    required double grossAmount,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-qris',
        body: {
          'order_id': orderId,
          'gross_amount': grossAmount,
          'cart_items': cartItems,
        },
      );

      final data = response.data;
      
      if (data == null) {
        throw Exception('Received empty response from the server');
      }

      if (data['success'] == true && data['qris_url'] != null) {
        return data['qris_url'] as String;
      } else {
        throw Exception(data['error'] ?? 'Unknown error occurred while generating QRIS');
      }
    } on FunctionException catch (e) {
      throw Exception('Server Error: ${e.reasonPhrase ?? e.details ?? "Could not reach Edge Function"}');
    } catch (e) {
      throw Exception('Failed to generate payment QR: $e');
    }
  }
}
