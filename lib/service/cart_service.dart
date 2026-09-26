import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../model/reservation_model.dart';
import '../repository/order_repo.dart';
import '../util/log_service.dart';
import 'api_exception.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final OrderRepo orderRepo;

  CartService({required this.orderRepo});

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  final Map<int, Timer> _expiryTimers = {};

  bool add(DealModel deal) {
    if (deal.isSaleExpired) {
      return false;
    }
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.isReserving || existing.reservation == null) return false;
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return false;
      }
      existing.quantity++;
      existing.isReserving = true;
      items.refresh();
      _reserve(
        existing,
        quantity: existing.quantity,
        previousReservation: existing.reservation,
      );
    } else {
      final item = CartItemModel(deal: deal, isReserving: true);
      items.add(item);
      _reserve(item, quantity: 1, previousReservation: null);
    }
    _recount();
    return true;
  }

  Future<void> _reserve(
    CartItemModel item, {
    required int quantity,
    required ReservationModel? previousReservation,
  }) async {
    try {
      final reservation =
          await orderRepo.reserve(item.deal.id, quantity: quantity);
      if (!items.contains(item)) {
        await _release(reservation.id);
        return;
      }
      if (item.deal.isSaleExpired) {
        await _release(reservation.id);
        items.remove(item);
        _recount();
        _showMessage(
            'Sale ended', '${item.deal.name} was removed from your bag.');
        return;
      }
      item.reservation = reservation;
      item.isReserving = false;
      items.refresh();
      _scheduleExpiry(item);
      if (previousReservation != null) {
        await _release(previousReservation.id);
      }
    } on ApiException catch (e) {
      _rollbackReservation(item, previousReservation,
          initialMessage: previousReservation == null
              ? 'This item is no longer available.'
              : e.message.toString());
      LogService.error('reservation failed', e);
    } catch (e) {
      _rollbackReservation(item, previousReservation,
          initialMessage:
              previousReservation == null ? 'Please try again.' : e.toString());
      LogService.error('reservation failed', e);
    }
  }

  void _rollbackReservation(
    CartItemModel item,
    ReservationModel? previousReservation, {
    required String initialMessage,
  }) {
    if (!items.contains(item)) return;
    if (previousReservation == null) {
      items.remove(item);
      _recount();
      _showMessage('Could not add deal', initialMessage);
    } else {
      item.quantity = previousReservation.quantity;
      item.reservation = previousReservation;
      item.isReserving = false;
      items.refresh();
      _showMessage('Bag not updated', initialMessage);
    }
  }

  void _scheduleExpiry(CartItemModel item) {
    final reservation = item.reservation;
    if (reservation == null) return;
    _expiryTimers[item.deal.id]?.cancel();
    final now = DateTime.now();
    final saleEndsAt = item.deal.flashSaleEndsAt;
    final expiresAt =
        saleEndsAt == null || reservation.expiresAt.isBefore(saleEndsAt)
            ? reservation.expiresAt
            : saleEndsAt;
    final delay = expiresAt.difference(now);
    if (delay.isNegative || delay == Duration.zero) return;
    _expiryTimers[item.deal.id] = Timer(delay, () {
      _expiryTimers.remove(item.deal.id);
      final current =
          items.firstWhereOrNull((line) => line.deal.id == item.deal.id);
      if (current == item && current?.reservation?.id == reservation.id) {
        remove(item.deal.id);
        if (item.deal.isSaleExpired) {
          _showMessage(
              'Sale ended', '${item.deal.name} was removed from your bag.');
        } else {
          _showMessage('Reservation expired',
              '${item.deal.name} was removed from your bag.');
        }
      }
    });
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null || existing.isReserving) return;
    if (existing.quantity == 1) {
      remove(dealId);
      return;
    }
    final previousReservation = existing.reservation;
    if (previousReservation == null) return;
    existing.quantity--;
    existing.isReserving = true;
    items.refresh();
    _reserve(
      existing,
      quantity: existing.quantity,
      previousReservation: previousReservation,
    );
    _recount();
  }

  void remove(int dealId) {
    _expiryTimers.remove(dealId)?.cancel();
    final item = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (item == null) return;
    items.remove(item);
    _recount();
    final reservationId = item.reservation?.id;
    if (reservationId != null) unawaited(_release(reservationId));
  }

  Future<void> _release(String reservationId) async {
    try {
      await orderRepo.releaseReservation(reservationId);
    } catch (e) {
      LogService.error('release reservation failed', e);
    }
  }

  void _showMessage(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  bool get hasPendingReservations => items.any((item) => item.isReserving);

  void clear() {
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    for (final item in items) {
      final reservationId = item.reservation?.id;
      if (reservationId != null) unawaited(_release(reservationId));
    }
    items.clear();
    _recount();
  }

  @override
  void onClose() {
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    super.onClose();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
