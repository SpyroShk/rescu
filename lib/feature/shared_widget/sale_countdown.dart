import 'dart:async';

import 'package:flutter/material.dart';

/// Live countdown until the sale window opens.
class SellCountdown extends StatelessWidget {
  final DateTime? endsAt;

  const SellCountdown({super.key, this.endsAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: _CountdownText(endsAt: endsAt),
    );
  }
}

class _CountdownText extends StatefulWidget {
  final DateTime? endsAt;

  const _CountdownText({required this.endsAt});

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt?.difference(DateTime.now());
    final String text;
    if (remaining == null || remaining.isNegative) {
      text = 'Expired';
    } else {
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      final s = remaining.inSeconds % 60;
      text =
          'Expires in ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return Text(text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700));
  }
}
