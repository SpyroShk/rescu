import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/home/widget/flash_deal_item.dart';
import 'package:rescu/feature/shared_widget/deal_item.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../model/deal_model.dart';
import '../../service/analytics_service.dart';

/// Deal card used in the home feed and search results.
class DealCard extends StatefulWidget {
  final DealModel deal;
  final String source;
  final int position;
  final bool isFlashDeal;

  const DealCard({
    super.key,
    required this.deal,
    required this.source,
    required this.position,
    this.isFlashDeal = false,
  });

  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  Timer? _visibilityTimer;
  bool _impressionSent = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_impressionSent) return;
    if (info.visibleFraction >= 0.5) {
      _visibilityTimer ??= Timer(const Duration(seconds: 1), () {
        _visibilityTimer = null;
        if (!mounted || _impressionSent) return;
        _impressionSent = true;
        Get.find<AnalyticsService>().logDealImpression(
          dealId: widget.deal.id,
          source: widget.source,
          position: widget.position,
        );
      });
    } else {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
    }
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(
          'deal-impression-${widget.source}-${widget.deal.id}-${widget.position}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: (widget.isFlashDeal)
          ? FlashDealItem(
              deal: widget.deal,
              source: widget.source,
            )
          : DealItem(
              deal: widget.deal,
              source: widget.source,
            ),
    );
  }
}
