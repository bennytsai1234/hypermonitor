import 'package:flutter/material.dart';

class SentimentBadge extends StatelessWidget {
  final String sentiment;

  const SentimentBadge({super.key, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final bool isBearish = sentiment.contains("跌");
    final Color color = isBearish ? const Color(0xFFFF4949) : const Color(0xFF00C087);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isBearish ? Icons.trending_down : Icons.trending_up, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            sentiment,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
