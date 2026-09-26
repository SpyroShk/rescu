import 'dart:async';

import 'package:get/get.dart';

import '../util/log_service.dart';
import 'fake_api_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink. Events are visible on the debug screen
/// (overflow menu on Home -> "Analytics debug") and in the console.
///
/// The "Impression tracking" feature task builds on top of this service.
class AnalyticsService extends GetxService {
  final FakeApiService api;

  AnalyticsService({required this.api});

  final events = <AnalyticsEvent>[].obs;
  final List<AnalyticsEvent> _pendingImpressions = [];
  final Set<int> _impressedDealIds = {};
  Timer? _flushTimer;
  bool _isFlushing = false;

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }

  void logDealImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    if (!_impressedDealIds.add(dealId)) return;

    final event = AnalyticsEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
    events.add(event);
    _pendingImpressions.add(event);
    LogService.log('analytics: deal_impression ${event.properties}');

    if (_pendingImpressions.length >= 10) {
      unawaited(_flushImpressions());
    } else {
      _flushTimer ??= Timer(const Duration(seconds: 15), () {
        _flushTimer = null;
        unawaited(_flushImpressions());
      });
    }
  }

  Future<void> _flushImpressions() async {
    if (_isFlushing || _pendingImpressions.isEmpty) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    _isFlushing = true;
    final batch = List<AnalyticsEvent>.from(_pendingImpressions);
    _pendingImpressions.removeRange(0, batch.length);
    try {
      await api
          .sendAnalyticsBatch(batch.map((event) => event.toJson()).toList());
    } catch (e) {
      _pendingImpressions.insertAll(0, batch);
      LogService.error('analytics flush failed', e);
    } finally {
      _isFlushing = false;
      if (_pendingImpressions.isNotEmpty && _flushTimer == null) {
        _flushTimer = Timer(const Duration(seconds: 15), () {
          _flushTimer = null;
          unawaited(_flushImpressions());
        });
      }
    }
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    super.onClose();
  }
}
