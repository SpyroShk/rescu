import 'package:get/get.dart';
import 'package:rescu/util/log_service.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  final deal = Rxn<DealModel>();
  final errorMessage = RxnString();
  Worker? _cartChangeWorker;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is DealModel) {
      _setDeal(argument);
    } else {
      final id = int.tryParse(Get.parameters['id'] ?? '');
      if (id == null) {
        errorMessage.value = 'Deal not found';
      } else {
        _loadDeal(id);
      }
    }
    analytics.logEvent('deal_details_view', {
      'deal_id': (argument is DealModel)
          ? argument.id
          : Get.parameters['id'] ?? 'unknown',
      'source': Get.parameters['source'] ?? 'unknown',
    });
    // Whenever the cart changes, re-check this deal's remaining stock so the
    // details screen never shows stale availability.
    _cartChangeWorker = ever(cartService.itemCount, (_) {
      return _recheckAvailability();
    });
  }

  @override
  void onClose() {
    _cartChangeWorker?.dispose();
    super.onClose();
  }

  Future<void> _recheckAvailability() async {
    final currentDeal = deal.value;
    if (currentDeal == null) return;
    LogService.log('re-checking availability for deal ${currentDeal.id}');
    final fresh = await dealRepo.fetchById(currentDeal.id);
    _quantityLeft.value = fresh.quantityLeft;
  }

  Future<void> _loadDeal(int id) async {
    try {
      _setDeal(await dealRepo.fetchById(id));
    } catch (e) {
      LogService.error('load deal failed', e);
      errorMessage.value = 'Unable to load deal';
    }
  }

  void _setDeal(DealModel value) {
    deal.value = value;
    _quantityLeft.value = value.quantityLeft;
  }

  void addToCart() {
    final currentDeal = deal.value;
    if (currentDeal == null) return;
    if (currentDeal.isSaleExpired) {
      Get.snackbar(
        'Sale ended',
        'This deal is no longer available',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!cartService.add(currentDeal)) return;
    Get.snackbar(
      'Added to bag',
      '${currentDeal.name} — pick up ${currentDeal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
