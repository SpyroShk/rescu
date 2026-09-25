import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  final Map<int, Timer> _expiryTimers = {};

  bool add(DealModel deal) {
    if (deal.isSaleExpired) {
      return false;
    }
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return false;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _scheduleExpiry(deal);
    _recount();
    return true;
  }

  void _scheduleExpiry(DealModel deal) {
    final endsAt = deal.flashSaleEndsAt;
    if (endsAt == null) return;
    _expiryTimers[deal.id]?.cancel();
    final delay = endsAt.difference(DateTime.now());
    if (delay.isNegative || delay == Duration.zero) return;
    _expiryTimers[deal.id] = Timer(delay, () {
      _expiryTimers.remove(deal.id);
      if (items.any((item) => item.deal.id == deal.id)) {
        remove(deal.id);
        Get.snackbar(
          'Deal expired',
          '${deal.name} was removed from your bag',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    _expiryTimers.remove(dealId)?.cancel();
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  void clear() {
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
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
