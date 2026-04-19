import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../../domain/models/analytics_data.dart';
import '../../data/repositories/analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(supabaseProvider));
});

class AnalyticsState {
  const AnalyticsState({
    required this.selectedPeriod,
    this.data,
  });

  final String selectedPeriod;
  final AnalyticsData? data;

  AnalyticsState copyWith({
    String? selectedPeriod,
    AnalyticsData? data,
  }) {
    return AnalyticsState(
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      data: data ?? this.data,
    );
  }
}

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  @override
  Future<AnalyticsState> build() async {
    final activeOutlet = ref.watch(activeOutletProvider);
    
    // Default config: 'daily'
    const initialPeriod = 'daily';

    final repo = ref.read(analyticsRepositoryProvider);
    final initialMetrics = await repo.fetchDashboardMetrics(
      period: initialPeriod,
      outletId: activeOutlet?.id,
    );

    return AnalyticsState(
      selectedPeriod: initialPeriod,
      data: initialMetrics,
    );
  }

  void updateFilters({required String newPeriod}) async {
    final activeOutlet = ref.read(activeOutletProvider);

    if (!state.hasValue) return;

    final currentState = state.value!;
    state = const AsyncLoading();

    try {
      final repo = ref.read(analyticsRepositoryProvider);
      final newData = await repo.fetchDashboardMetrics(
        period: newPeriod,
        outletId: activeOutlet?.id,
      );

      state = AsyncData(currentState.copyWith(
        selectedPeriod: newPeriod,
        data: newData,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    if (!state.hasValue) return;
    updateFilters(newPeriod: state.value!.selectedPeriod);
  }
}

final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
  AnalyticsNotifier.new,
);
