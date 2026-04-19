import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/analytics_data.dart';
import '../../../pos/domain/entities/outlet.dart';

class AnalyticsRepository {
  const AnalyticsRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<Outlet>> fetchOutlets() async {
    try {
      final data = await _supabase
          .from('outlets')
          .select('id, name, address')
          .order('name');
          
      return (data as List).map((o) => Outlet.fromJson(o)).toList();
    } catch (e) {
      throw Exception('Failed to load outlets: $e');
    }
  }

  Future<AnalyticsData> fetchDashboardMetrics({
    required String period,
    String? outletId,
  }) async {
    try {
      // Setup payload matching the PostgreSQL RPC params
      final Map<String, dynamic> params = {'p_period': period};
      if (outletId != null && outletId.isNotEmpty) {
        params['p_outlet_id'] = outletId;
      }

      final dynamic response = await _supabase.rpc('get_dashboard_metrics', params: params);

      if (response == null) {
        throw Exception('Received null data from metrics RPC');
      }

      return AnalyticsData.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load analytics: $e');
    }
  }
}
