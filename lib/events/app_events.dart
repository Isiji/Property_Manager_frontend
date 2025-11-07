// lib/events/app_events.dart
import 'dart:async';

/// Simple broadcast event bus for lightweight cross-screen notifications.
/// We only need a signal that "a payment was initiated/updated".
class AppEvents {
  AppEvents._();
  static final AppEvents I = AppEvents._();

  /// Emitted after STK initiation succeeds (tenant pressed Pay Now).
  /// The event doesn’t carry data; listeners can just refresh what they need.
  final StreamController<void> paymentActivity = StreamController<void>.broadcast();

  void dispose() {
    paymentActivity.close();
  }
}
