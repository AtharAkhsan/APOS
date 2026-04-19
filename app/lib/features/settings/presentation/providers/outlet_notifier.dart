import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/outlet_repository.dart';
import '../../domain/entities/outlet.dart';

class OutletNotifier extends AsyncNotifier<List<Outlet>> {
  @override
  Future<List<Outlet>> build() => _fetch();

  Future<List<Outlet>> _fetch() {
    return ref.read(outletRepositoryProvider).getOutlets();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> addOutlet(Outlet outlet) async {
    final repo = ref.read(outletRepositoryProvider);
    final created = await repo.createOutlet(outlet);
    state = AsyncData([created, ...state.value ?? []]);
  }

  Future<void> updateOutlet(Outlet outlet) async {
    final repo = ref.read(outletRepositoryProvider);
    final updated = await repo.updateOutlet(outlet);
    final list = [...?state.value];
    final idx = list.indexWhere((o) => o.id == updated.id);
    if (idx >= 0) list[idx] = updated;
    state = AsyncData(list);
  }

  Future<void> deactivateOutlet(String id) async {
    final repo = ref.read(outletRepositoryProvider);
    await repo.deactivateOutlet(id);
    final list = [...?state.value];
    list.removeWhere((o) => o.id == id);
    state = AsyncData(list);
  }
}

final outletNotifierProvider =
    AsyncNotifierProvider<OutletNotifier, List<Outlet>>(
  OutletNotifier.new,
);
