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

  String _formatValue(double v) {
    if (v.abs() >= 1e8) return "${(v / 1e8).toStringAsFixed(2)}億";
    if (v.abs() >= 1e4) return "${(v / 1e4).toStringAsFixed(0)}萬";
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final total = leftVal + rightVal;
    final leftPct = total > 0 ? (leftVal / total) : 0.5;
    final rightPct = 1.0 - leftPct;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              Text(
                "${(leftPct * 100).toStringAsFixed(1)}% : ${(rightPct * 100).toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(flex: (leftPct * 1000).round(), child: Container(color: leftColor.withAlpha(200))),
                      Expanded(flex: (rightPct * 1000).round(), child: Container(color: rightColor.withAlpha(200))),
                    ],
                  ),
                ),
              ),
              Container(width: 1.5, height: 14, color: Colors.white),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$leftLabel: ${_formatValue(leftVal)}", style: TextStyle(color: leftColor, fontSize: 8, fontWeight: FontWeight.bold)),
              Text("$rightLabel: ${_formatValue(rightVal)}", style: TextStyle(color: rightColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
