import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;
  SearchDealsController({required this.dealRepo});
  Timer? _debounce;
  int _searchId = 0; // increments with every new search

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  void onQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final int thisSearchId = ++_searchId; // stamp this request

    if (query.trim().isEmpty) {
      results.clear();
      hasSearched.value = false;
      return;
    }
    isLoading.value = true;
    hasSearched.value = true;
    try {
      final found = await dealRepo.search(query);
      if (thisSearchId != _searchId) {
        return; // a newer search has started, discard this result
      }
      results.assignAll(found);
    } catch (e) {
      if (thisSearchId != _searchId) {
        return; // don't report errors either if id matches
      }
      LogService.error('search failed', e);
    } finally {
      if (thisSearchId == _searchId) {
        isLoading.value =
            false; // only the latest search controls the loading spinner
      }
    }
  }

  @override
  void onClose() {
    _debounce?.cancel(); // always clean up
    super.onClose();
  }
}
