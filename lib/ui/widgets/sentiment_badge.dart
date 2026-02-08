import 'package:flutter/material.dart';

class SentimentBadge extends StatelessWidget {
  final String sentiment;

  const SentimentBadge({super.key, required this.sentiment});

  Color _getSentimentColor(String text) {
    if (text.contains("非常")) {
      return (text.contains("跌")) ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
    } else if (text.contains("略")) {
      return (text.contains("跌")) ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7);
    } else if (text.contains("跌")) {
      return const Color(0xFFFF4949);
    } else if (text.contains("漲") || text.contains("涨")) {
      return const Color(0xFF00C087);
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = _getSentimentColor(sentiment);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Text(
        sentiment,
        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}