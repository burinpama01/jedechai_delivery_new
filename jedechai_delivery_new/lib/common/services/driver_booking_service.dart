import '../models/booking.dart';
import 'booking_service.dart';

/// Driver-specific booking operations — delegates to BookingService.
///
/// Extracted from BookingService as part of Sprint 5.1 refactor.
/// BookingService still owns the full implementations; this class
/// provides a focused surface for driver screens.
class DriverBookingService {
  final BookingService _bookingService;

  DriverBookingService({BookingService? bookingService})
      : _bookingService = bookingService ?? BookingService();

  /// Returns bookings available for drivers to accept.
  Future<List<Booking>> getPendingBookings() =>
      _bookingService.getPendingBookings();

  /// Accepts a booking on behalf of the driver (includes wallet check).
  Future<void> acceptBooking(String bookingId) =>
      _bookingService.acceptBooking(bookingId);

  /// Atomically completes a booking and handles financial settlement.
  Future<void> completeBooking(String bookingId) =>
      _bookingService.completeBooking(bookingId);

  /// Updates booking status (non-terminal transitions).
  Future<void> updateBookingStatus(String bookingId, String newStatus) =>
      _bookingService.updateBookingStatus(bookingId, newStatus);

  Future<void> updateBookingStatusGuarded(
    String bookingId,
    String newStatus, {
    required List<String> expectedStatuses,
  }) =>
      _bookingService.updateBookingStatusGuarded(
        bookingId,
        newStatus,
        expectedStatuses: expectedStatuses,
      );

  Future<void> markDriverArrivedAtMerchant(String bookingId) =>
      _bookingService.markDriverArrivedAtMerchant(bookingId);

  Future<void> markFoodPickedUp(String bookingId) =>
      _bookingService.markFoodPickedUp(bookingId);
}
