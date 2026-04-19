import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/domain/entities/outlet.dart';

/// Holds the currently active outlet across the app.
/// Defaults to the first outlet from the database.
/// An outlet of `null` explicitly implies "All Outlets".
class ActiveOutletNotifier extends Notifier<Outlet?> {
  @override
  Outlet? build() {
    // We default to 'null' globally to represent "All Outlets",
    // satisfying the requirement for Dashboard and Accounting.
    // If a view (like POS) requires a specific outlet, it has fallback logic to auto-select one.
    return null;
  }

  void setOutlet(Outlet? outlet) {
    state = outlet;
  }
}

final activeOutletProvider = NotifierProvider<ActiveOutletNotifier, Outlet?>(
  ActiveOutletNotifier.new,
);
