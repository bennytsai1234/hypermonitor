import 'package:flutter/material.dart';

class TugOfWarBar extends StatelessWidget {
  final String label;
  final double leftVal;
  final double rightVal;
  final Color leftColor;
  final Color rightColor;
  final String leftLabel;
  final String rightLabel;
  final Color cardBg;

  const TugOfWarBar({
    super.key,
    required this.label,
    required this.leftVal,
    required this.rightVal,
    required this.leftColor,
    required this.rightColor,
    required this.leftLabel,
    required this.rightLabel,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    final total = leftVal + rightVal;
    final leftPct = total > 0 ? (leftVal / total) : 0.5;
    final rightPct = total > 0 ? (rightVal / total) : 0.5;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("${(leftPct * 100).toStringAsFixed(1)}% vs ${(rightPct * 100).toStringAsFixed(1)}%", 
                style: const TextStyle(color: Colors.white24, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(flex: (leftPct * 100).round(), child: Container(color: leftColor)),
                  const SizedBox(width: 1),
                  Expanded(flex: (rightPct * 100).round(), child: Container(color: rightColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftLabel, style: TextStyle(color: leftColor.withAlpha(180), fontSize: 9, fontWeight: FontWeight.bold)),
              Text(rightLabel, style: TextStyle(color: rightColor.withAlpha(180), fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
