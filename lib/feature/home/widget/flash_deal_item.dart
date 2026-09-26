import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rescu/app_config.dart';
import 'package:rescu/feature/shared_widget/sale_countdown.dart';
import 'package:rescu/feature/shared_widget/the_network_image.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/routes/routes.dart';

class FlashDealItem extends StatelessWidget {
  const FlashDealItem({
    super.key,
    required this.deal,
    required this.source,
  });
  final DealModel deal;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => Get.toNamed(
          Routes.dealRoute(deal.id, source: 'flash_rail'),
          arguments: deal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TheNetworkImage(
                url: deal.imageUrl, height: 90, width: double.infinity),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(deal.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('฿${deal.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppConfig.primaryGreen)),
                      const Spacer(),
                      if (deal.flashSaleEndsAt != null)
                        SellCountdown(endsAt: deal.flashSaleEndsAt),
                      // Container(
                      //   padding: const EdgeInsets.symmetric(
                      //       horizontal: 6, vertical: 2),
                      //   decoration: BoxDecoration(
                      //     color: Colors.red.shade50,
                      //     borderRadius: BorderRadius.circular(4),
                      //   ),
                      //   child: Text('Ends soon',
                      //       style: TextStyle(
                      //           fontSize: 11,
                      //           fontWeight: FontWeight.w600,
                      //           color: Colors.red.shade700)),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
