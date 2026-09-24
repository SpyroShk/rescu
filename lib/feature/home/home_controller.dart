import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  // final scrollOffset = 0.0.obs;
  final showScrollToTop = false.obs;
  final isScrolled = false.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;
  bool _isRefreshing = false;
  int _feedGeneration = 0;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    // scrollOffset.value = scrollController.offset;
    final scrolled = scrollController.offset > 4;
    if (scrolled != isScrolled.value) isScrolled.value = scrolled;

    final showFab = scrollController.offset > 800;
    if (showFab != showScrollToTop.value) showScrollToTop.value = showFab;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    final generation = ++_feedGeneration;
    _isRefreshing = true;
    try {
      final res = await dealRepo.fetchDeals(page: 1);
      if (generation != _feedGeneration) return;
      _page = 1;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      log(deals.length.toString());
    } finally {
      _isRefreshing = false;
      refreshController.refreshCompleted();
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || _isRefreshing) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }
    _isFetchingMore = true;
    final generation = _feedGeneration;
    final requestedPage = _page + 1;
    try {
      final res = await dealRepo.fetchDeals(page: requestedPage);
      if (generation != _feedGeneration) return;
      _page = requestedPage;
      _totalPages = res.totalPages;
      deals.addAll(res.items);
      log(deals.length.toString());
    } catch (e) {
      LogService.error('loadMore failed', e);
    } finally {
      _isFetchingMore = false;
      refreshController.loadComplete();
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
